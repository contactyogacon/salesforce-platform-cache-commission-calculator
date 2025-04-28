/**
 * Service class for calculating commissions
 * This is the uncached version that performs direct SOQL queries
 */
public class CommissionCalculatorService {
    
    /**
     * Calculate commission for a single sales rep for a specific period
     * @param salesRepId The ID of the sales rep
     * @param period The period in format YYYY-MM
     * @return The calculated commission statement
     */
    public Commission_Statement__c calculateCommission(Id salesRepId, String period) {
        TimeLogger.startTimer('calculateCommission');
        
        // Get the sales rep
        TimeLogger.startTimer('getSalesRep');
        Sales_Rep__c salesRep = getSalesRep(salesRepId);
        TimeLogger.endTimer('getSalesRep');
        
        // Parse the period
        String[] periodParts = period.split('-');
        Integer year = Integer.valueOf(periodParts[0]);
        Integer month = Integer.valueOf(periodParts[1]);
        
        // Calculate start and end dates for the period
        Date startDate = Date.newInstance(year, month, 1);
        Date endDate;
        if (month == 12) {
            endDate = Date.newInstance(year + 1, 1, 1).addDays(-1);
        } else {
            endDate = Date.newInstance(year, month + 1, 1).addDays(-1);
        }
        
        // Get all opportunities for this sales rep in the period
        TimeLogger.startTimer('getOpportunities');
        List<Opportunity> opportunities = getOpportunities(salesRep.User__c, startDate, endDate);
        TimeLogger.endTimer('getOpportunities');
        
        // Get all commission rules
        TimeLogger.startTimer('getCommissionRules');
        List<Commission_Rules__c> commissionRules = getCommissionRules(salesRep.Region__c, salesRep.Seniority_Level__c, startDate, endDate);
        TimeLogger.endTimer('getCommissionRules');
        
        // Get all active promotions
        TimeLogger.startTimer('getPromotions');
        List<Promotion__c> promotions = getPromotions(salesRep.Region__c, startDate, endDate);
        TimeLogger.endTimer('getPromotions');
        
        // Get exchange rates
        TimeLogger.startTimer('getExchangeRates');
        Map<String, Decimal> exchangeRates = getExchangeRates(startDate, endDate);
        TimeLogger.endTimer('getExchangeRates');
        
        // Get team performance data
        TimeLogger.startTimer('getTeamPerformance');
        Team__c team = getTeam(salesRep.Team__c);
        TimeLogger.endTimer('getTeamPerformance');
        
        // Calculate commission
        TimeLogger.startTimer('processCommission');
        Commission_Statement__c statement = processCommission(salesRep, opportunities, commissionRules, promotions, exchangeRates, team, period);
        TimeLogger.endTimer('processCommission');
        
        TimeLogger.endTimer('calculateCommission');
        return statement;
    }
    
    /**
     * Get a sales rep by ID
     * @param salesRepId The ID of the sales rep
     * @return The sales rep record
     */
    private Sales_Rep__c getSalesRep(Id salesRepId) {
        return [
            SELECT Id, Name, User__c, Region__c, Seniority_Level__c, Team__c, 
                   YTD_Sales__c, Quarter_Sales__c
            FROM Sales_Rep__c
            WHERE Id = :salesRepId
        ];
    }
    
    /**
     * Get all opportunities for a user in a specific date range
     * @param userId The ID of the user
     * @param startDate The start date
     * @param endDate The end date
     * @return List of opportunities
     */
    private List<Opportunity> getOpportunities(Id userId, Date startDate, Date endDate) {
        return [
            SELECT Id, Name, Amount, CloseDate,
                  (SELECT Id, Product2Id, Product2.Name, Product2.Family, UnitPrice, Quantity, TotalPrice
                   FROM OpportunityLineItems)
            FROM Opportunity
            WHERE OwnerId = :userId
            AND CloseDate >= :startDate
            AND CloseDate <= :endDate
            AND StageName = 'Closed Won'
        ];
    }
    
    /**
     * Get all commission rules applicable to a sales rep
     * @param region The region of the sales rep
     * @param seniorityLevel The seniority level of the sales rep
     * @param startDate The start date
     * @param endDate The end date
     * @return List of commission rules
     */
    private List<Commission_Rules__c> getCommissionRules(String region, String seniorityLevel, Date startDate, Date endDate) {
        return [
            SELECT Id, Name, Product_Category__c, Region__c, Seniority_Level__c,
                   Min_Amount__c, Max_Amount__c, Commission_Rate__c
            FROM Commission_Rules__c
            WHERE Is_Active__c = true
            AND ((Region__c = :region) OR (Region__c = 'Global'))
            AND ((Seniority_Level__c = :seniorityLevel) OR (Seniority_Level__c = 'All'))
            AND Start_Date__c <= :endDate
            AND (End_Date__c >= :startDate OR End_Date__c = null)
            ORDER BY Product_Category__c, Min_Amount__c
        ];
    }
    
    /**
     * Get all active promotions
     * @param region The region of the sales rep
     * @param startDate The start date
     * @param endDate The end date
     * @return List of promotions
     */
    private List<Promotion__c> getPromotions(String region, Date startDate, Date endDate) {
        return [
            SELECT Id, Name, Product_Category__c, Region__c, Bonus_Rate__c
            FROM Promotion__c
            WHERE Is_Active__c = true
            AND ((Region__c = :region) OR (Region__c = 'Global'))
            AND Start_Date__c <= :endDate
            AND End_Date__c >= :startDate
        ];
    }
    
    /**
     * Get exchange rates for the period
     * @param startDate The start date
     * @param endDate The end date
     * @return Map of currency pairs to exchange rates
     */
    private Map<String, Decimal> getExchangeRates(Date startDate, Date endDate) {
        Map<String, Decimal> rates = new Map<String, Decimal>();
        
        // Get the latest exchange rate for each currency pair in the period
        List<Exchange_Rate__c> exchangeRates = [
            SELECT Id, From_Currency__c, To_Currency__c, Rate__c, Effective_Date__c
            FROM Exchange_Rate__c
            WHERE Effective_Date__c <= :endDate
            ORDER BY From_Currency__c, To_Currency__c, Effective_Date__c DESC
        ];
        
        // Create a map of the latest exchange rate for each currency pair
        Map<String, Exchange_Rate__c> latestRates = new Map<String, Exchange_Rate__c>();
        for (Exchange_Rate__c rate : exchangeRates) {
            String key = rate.From_Currency__c + '-' + rate.To_Currency__c;
            if (!latestRates.containsKey(key)) {
                latestRates.put(key, rate);
                rates.put(key, rate.Rate__c);
            }
        }
        
        return rates;
    }
    
    /**
     * Get team data
     * @param teamId The ID of the team
     * @return The team record
     */
    private Team__c getTeam(Id teamId) {
        return [
            SELECT Id, Name, Region__c, Quarter_Target__c, Year_Target__c,
                   Quarter_Achieved__c, Year_Achieved__c
            FROM Team__c
            WHERE Id = :teamId
        ];
    }
    
    /**
     * Process commission calculation
     * @param salesRep The sales rep
     * @param opportunities The opportunities
     * @param commissionRules The commission rules
     * @param promotions The promotions
     * @param exchangeRates The exchange rates
     * @param team The team
     * @param period The period
     * @return The calculated commission statement
     */
    private Commission_Statement__c processCommission(
        Sales_Rep__c salesRep, 
        List<Opportunity> opportunities,
        List<Commission_Rules__c> commissionRules,
        List<Promotion__c> promotions,
        Map<String, Decimal> exchangeRates,
        Team__c team,
        String period
    ) {
        // Create a new commission statement
        Commission_Statement__c statement = new Commission_Statement__c(
            Sales_Rep__c = salesRep.Id,
            Period__c = period,
            Total_Sales__c = 0,
            Base_Commission__c = 0,
            Team_Bonus__c = 0,
            Promotion_Bonus__c = 0,
            Total_Commission__c = 0,
            Status__c = 'Draft',
            Calculation_Date__c = System.now()
        );
        
        // Insert the statement to get an ID
        insert statement;
        
        // Process each opportunity
        List<Commission_Detail__c> details = new List<Commission_Detail__c>();
        
        for (Opportunity opp : opportunities) {
            // Convert opportunity amount to corporate currency if needed
            Decimal exchangeRate = 1.0;
            String defaultCurrency = 'USD'; // Default currency since multi-currency is not enabled
            
            // Process each line item
            for (OpportunityLineItem lineItem : opp.OpportunityLineItems) {
                // Find the applicable commission rule
                Commission_Rules__c applicableRule = findCommissionRule(
                    commissionRules, 
                    lineItem.Product2.Family, 
                    lineItem.TotalPrice * exchangeRate
                );
                
                if (applicableRule != null) {
                    // Calculate base commission
                    Decimal commissionRate = applicableRule.Commission_Rate__c;
                    Decimal commissionAmount = lineItem.TotalPrice * exchangeRate * commissionRate;
                    
                    // Find applicable promotions
                    Decimal promotionBonus = calculatePromotionBonus(
                        promotions, 
                        lineItem.Product2.Family, 
                        lineItem.TotalPrice * exchangeRate
                    );
                    
                    // Create commission detail record
                    Commission_Detail__c detail = new Commission_Detail__c(
                        Commission_Statement__c = statement.Id,
                        Opportunity__c = opp.Id,
                        Product__c = lineItem.Product2Id,
                        Product_Category__c = lineItem.Product2.Family,
                        Sales_Amount__c = lineItem.TotalPrice * exchangeRate,
                        Commission_Rate__c = commissionRate,
                        Commission_Amount__c = commissionAmount,
                        Promotion_Bonus__c = promotionBonus,
                        Exchange_Rate__c = exchangeRate,
                        Original_Currency__c = defaultCurrency
                    );
                    
                    details.add(detail);
                    
                    // Update statement totals
                    statement.Total_Sales__c += lineItem.TotalPrice * exchangeRate;
                    statement.Base_Commission__c += commissionAmount;
                    statement.Promotion_Bonus__c += promotionBonus;
                }
            }
        }
        
        // Insert all commission details
        if (!details.isEmpty()) {
            insert details;
        }
        
        // Calculate team bonus
        Decimal teamBonus = calculateTeamBonus(team, salesRep, statement.Total_Sales__c);
        statement.Team_Bonus__c = teamBonus;
        
        // Calculate total commission
        statement.Total_Commission__c = statement.Base_Commission__c + statement.Team_Bonus__c + statement.Promotion_Bonus__c;
        
        // Update the statement
        update statement;
        
        //System.debug('Commission calculation results:');
        //System.debug('Total Sales: ' + statement.Total_Sales__c);
        //System.debug('Base Commission: ' + statement.Base_Commission__c);
        //System.debug('Team Bonus: ' + statement.Team_Bonus__c);
        //System.debug('Promotion Bonus: ' + statement.Promotion_Bonus__c);
        System.debug('Total Commission: ' + statement.Total_Commission__c);

        return statement;
    }
    
    /**
     * Find the applicable commission rule for a product category and amount
     * @param rules The list of commission rules
     * @param productCategory The product category
     * @param amount The amount
     * @return The applicable commission rule
     */
    private Commission_Rules__c findCommissionRule(List<Commission_Rules__c> rules, String productCategory, Decimal amount) {
        for (Commission_Rules__c rule : rules) {
            if ((rule.Product_Category__c == productCategory || rule.Product_Category__c == 'All') && 
                amount >= rule.Min_Amount__c && 
                (rule.Max_Amount__c == null || amount <= rule.Max_Amount__c)) {
                return rule;
            }
        }
        return null;
    }
    
    /**
     * Calculate promotion bonus
     * @param promotions The list of promotions
     * @param productCategory The product category
     * @param amount The amount
     * @return The promotion bonus
     */
    private Decimal calculatePromotionBonus(List<Promotion__c> promotions, String productCategory, Decimal amount) {
        Decimal bonus = 0;
        
        for (Promotion__c promo : promotions) {
            if (promo.Product_Category__c == productCategory || promo.Product_Category__c == 'All') {
                bonus += amount * promo.Bonus_Rate__c;
            }
        }
        
        return bonus;
    }
    
    /**
     * Calculate team bonus
     * @param team The team
     * @param salesRep The sales rep
     * @param totalSales The total sales
     * @return The team bonus
     */
    private Decimal calculateTeamBonus(Team__c team, Sales_Rep__c salesRep, Decimal totalSales) {
        Decimal bonus = 0;
        
        // Check if team has met quarterly target
        if (team.Quarter_Achieved__c >= team.Quarter_Target__c) {
            // 1% team bonus if target met
            bonus += totalSales * 0.01;
        }
        
        // Check if team has met yearly target
        if (team.Year_Achieved__c >= team.Year_Target__c) {
            // Additional 0.5% team bonus if yearly target met
            bonus += totalSales * 0.005;
        }
        
        return bonus;
    }
    
    /**
     * Calculate commissions for all sales reps in a batch process
     * @param period The period in format YYYY-MM
     * @return List of commission statements
     */
    public List<Commission_Statement__c> calculateCommissionsForAllReps(String period) {
        TimeLogger.startTimer('calculateCommissionsForAllReps');
        
        // Get all sales reps
        TimeLogger.startTimer('getAllSalesReps');
        List<Sales_Rep__c> salesReps = [
            SELECT Id, Name, User__c, Region__c, Seniority_Level__c, Team__c, 
                   YTD_Sales__c, Quarter_Sales__c
            FROM Sales_Rep__c
        ];
        TimeLogger.endTimer('getAllSalesReps');
        
        List<Commission_Statement__c> statements = new List<Commission_Statement__c>();
        
        // Calculate commission for each sales rep
        for (Sales_Rep__c rep : salesReps) {
            Commission_Statement__c statement = calculateCommission(rep.Id, period);
            statements.add(statement);
        }
        
        TimeLogger.endTimer('calculateCommissionsForAllReps');
        return statements;
    }
    
    /**
     * Calculate a what-if commission for an opportunity
     * @param opportunityId The ID of the opportunity
     * @return The calculated commission amount
     */
    public Decimal calculateWhatIfCommission(Id opportunityId) {
        TimeLogger.startTimer('calculateWhatIfCommission');
        
        // Get the opportunity
        TimeLogger.startTimer('getOpportunity');
        Opportunity opp = [
            SELECT Id, Name, Amount, CloseDate, OwnerId,
                  (SELECT Id, Product2Id, Product2.Name, Product2.Family, UnitPrice, Quantity, TotalPrice
                   FROM OpportunityLineItems)
            FROM Opportunity
            WHERE Id = :opportunityId
        ];
        TimeLogger.endTimer('getOpportunity');
        
        // Get the sales rep
        TimeLogger.startTimer('getSalesRepForUser');
        Sales_Rep__c salesRep = [
            SELECT Id, Name, User__c, Region__c, Seniority_Level__c, Team__c
            FROM Sales_Rep__c
            WHERE User__c = :opp.OwnerId
            LIMIT 1
        ];
        TimeLogger.endTimer('getSalesRepForUser');
        
        // Get commission rules
        TimeLogger.startTimer('getCommissionRulesForWhatIf');
        List<Commission_Rules__c> commissionRules = [
            SELECT Id, Name, Product_Category__c, Region__c, Seniority_Level__c,
                   Min_Amount__c, Max_Amount__c, Commission_Rate__c
            FROM Commission_Rules__c
            WHERE Is_Active__c = true
            AND ((Region__c = :salesRep.Region__c) OR (Region__c = 'Global'))
            AND ((Seniority_Level__c = :salesRep.Seniority_Level__c) OR (Seniority_Level__c = 'All'))
            AND Start_Date__c <= :opp.CloseDate
            AND (End_Date__c >= :opp.CloseDate OR End_Date__c = null)
            ORDER BY Product_Category__c, Min_Amount__c
        ];
        TimeLogger.endTimer('getCommissionRulesForWhatIf');
        
        // Get promotions
        TimeLogger.startTimer('getPromotionsForWhatIf');
        List<Promotion__c> promotions = [
            SELECT Id, Name, Product_Category__c, Region__c, Bonus_Rate__c
            FROM Promotion__c
            WHERE Is_Active__c = true
            AND ((Region__c = :salesRep.Region__c) OR (Region__c = 'Global'))
            AND Start_Date__c <= :opp.CloseDate
            AND End_Date__c >= :opp.CloseDate
        ];
        TimeLogger.endTimer('getPromotionsForWhatIf');
        
        // Get exchange rates
        TimeLogger.startTimer('getExchangeRatesForWhatIf');
        Map<String, Decimal> exchangeRates = new Map<String, Decimal>();
        List<Exchange_Rate__c> exchangeRateRecords = [
            SELECT Id, From_Currency__c, To_Currency__c, Rate__c, Effective_Date__c
            FROM Exchange_Rate__c
            WHERE Effective_Date__c <= :opp.CloseDate
            ORDER BY From_Currency__c, To_Currency__c, Effective_Date__c DESC
        ];
        
        // Create a map of the latest exchange rate for each currency pair
        Map<String, Exchange_Rate__c> latestRates = new Map<String, Exchange_Rate__c>();
        for (Exchange_Rate__c rate : exchangeRateRecords) {
            String key = rate.From_Currency__c + '-' + rate.To_Currency__c;
            if (!latestRates.containsKey(key)) {
                latestRates.put(key, rate);
                exchangeRates.put(key, rate.Rate__c);
            }
        }
        TimeLogger.endTimer('getExchangeRatesForWhatIf');
        
        // Calculate commission
        TimeLogger.startTimer('calculateWhatIfAmount');
        Decimal totalCommission = 0;
        
        // Default exchange rate since multi-currency is not enabled
        Decimal exchangeRate = 1.0;
        String defaultCurrency = 'USD';
        
        // Process each line item
        for (OpportunityLineItem lineItem : opp.OpportunityLineItems) {
            // Find the applicable commission rule
            Commission_Rules__c applicableRule = findCommissionRule(
                commissionRules, 
                lineItem.Product2.Family, 
                lineItem.TotalPrice * exchangeRate
            );
            
            if (applicableRule != null) {
                // Calculate base commission
                Decimal commissionRate = applicableRule.Commission_Rate__c;
                Decimal commissionAmount = lineItem.TotalPrice * exchangeRate * commissionRate;
                
                // Find applicable promotions
                Decimal promotionBonus = calculatePromotionBonus(
                    promotions, 
                    lineItem.Product2.Family, 
                    lineItem.TotalPrice * exchangeRate
                );
                
                totalCommission += commissionAmount + promotionBonus;
            }
        }
        TimeLogger.endTimer('calculateWhatIfAmount');
        
        TimeLogger.endTimer('calculateWhatIfCommission');
        return totalCommission;
    }
}
