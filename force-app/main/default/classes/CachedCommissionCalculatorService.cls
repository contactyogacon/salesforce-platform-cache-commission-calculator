/**
 * Service class for calculating commissions with caching
 * This version uses Platform Cache to improve performance
 */
public class CachedCommissionCalculatorService {
    
    // Cache partition names
    private static final String ORG_PARTITION_NAME = 'local.CommissionCache';
    private static final String SESSION_PARTITION_NAME = 'local.CommissionCache';
    
    // Cache keys
    private static final String COMMISSION_RULES_KEY = 'commissionrules';
    private static final String EXCHANGE_RATES_KEY = 'exchangerates';
    private static final String PROMOTIONS_KEY = 'promotions';
    private static final String TEAM_KEY_PREFIX = 'team';
    
    // Cache TTL in seconds
    private static final Integer RULES_CACHE_TTL = 3600; // 1 hour
    private static final Integer RATES_CACHE_TTL = 86400; // 24 hours
    private static final Integer PROMOTIONS_CACHE_TTL = 3600; // 1 hour
    private static final Integer TEAM_CACHE_TTL = 1800; // 30 minutes
    
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
     * Get all commission rules applicable to a sales rep - CACHED VERSION
     * @param region The region of the sales rep
     * @param seniorityLevel The seniority level of the sales rep
     * @param startDate The start date
     * @param endDate The end date
     * @return List of commission rules
     */
    private List<Commission_Rules__c> getCommissionRules(String region, String seniorityLevel, Date startDate, Date endDate) {
        // Try to get from cache first
        Cache.OrgPartition orgPartition = Cache.Org.getPartition(ORG_PARTITION_NAME);
        String cacheKey = COMMISSION_RULES_KEY;
        
        List<Commission_Rules__c> rules;
        if (orgPartition.contains(cacheKey)) {
            TimeLogger.startTimer('getCommissionRulesFromCache');
            rules = (List<Commission_Rules__c>)orgPartition.get(cacheKey);
            TimeLogger.endTimer('getCommissionRulesFromCache');
            
            // Filter the cached rules based on the parameters
            TimeLogger.startTimer('filterCommissionRules');
            List<Commission_Rules__c> filteredRules = new List<Commission_Rules__c>();
            for (Commission_Rules__c rule : rules) {
                if (rule.Is_Active__c && 
                    (rule.Region__c == region || rule.Region__c == 'Global') &&
                    (rule.Seniority_Level__c == seniorityLevel || rule.Seniority_Level__c == 'All') &&
                    rule.Start_Date__c <= endDate &&
                    (rule.End_Date__c >= startDate || rule.End_Date__c == null)) {
                    filteredRules.add(rule);
                }
            }
            TimeLogger.endTimer('filterCommissionRules');
            return filteredRules;
        }
        
        // If not in cache, query and cache the result
        TimeLogger.startTimer('queryCommissionRules');
        rules = [
            SELECT Id, Name, Product_Category__c, Region__c, Seniority_Level__c,
                   Min_Amount__c, Max_Amount__c, Commission_Rate__c, Is_Active__c,
                   Start_Date__c, End_Date__c
            FROM Commission_Rules__c
            WHERE Is_Active__c = true
        ];
        TimeLogger.endTimer('queryCommissionRules');
        
        // Cache all rules
        TimeLogger.startTimer('cacheCommissionRules');
        orgPartition.put(cacheKey, rules, RULES_CACHE_TTL);
        TimeLogger.endTimer('cacheCommissionRules');
        
        // Filter the rules based on the parameters
        TimeLogger.startTimer('filterCommissionRules');
        List<Commission_Rules__c> filteredRules = new List<Commission_Rules__c>();
        for (Commission_Rules__c rule : rules) {
            if ((rule.Region__c == region || rule.Region__c == 'Global') &&
                (rule.Seniority_Level__c == seniorityLevel || rule.Seniority_Level__c == 'All') &&
                rule.Start_Date__c <= endDate &&
                (rule.End_Date__c >= startDate || rule.End_Date__c == null)) {
                filteredRules.add(rule);
            }
        }
        TimeLogger.endTimer('filterCommissionRules');
        
        return filteredRules;
    }
    
    /**
     * Get all active promotions - CACHED VERSION
     * @param region The region of the sales rep
     * @param startDate The start date
     * @param endDate The end date
     * @return List of promotions
     */
    private List<Promotion__c> getPromotions(String region, Date startDate, Date endDate) {
        // Try to get from cache first
        Cache.OrgPartition orgPartition = Cache.Org.getPartition(ORG_PARTITION_NAME);
        String cacheKey = PROMOTIONS_KEY;
        
        List<Promotion__c> promotions;
        if (orgPartition.contains(cacheKey)) {
            TimeLogger.startTimer('getPromotionsFromCache');
            promotions = (List<Promotion__c>)orgPartition.get(cacheKey);
            TimeLogger.endTimer('getPromotionsFromCache');
            
            // Filter the cached promotions based on the parameters
            TimeLogger.startTimer('filterPromotions');
            List<Promotion__c> filteredPromotions = new List<Promotion__c>();
            for (Promotion__c promo : promotions) {
                if (promo.Is_Active__c && 
                    (promo.Region__c == region || promo.Region__c == 'Global') &&
                    promo.Start_Date__c <= endDate &&
                    promo.End_Date__c >= startDate) {
                    filteredPromotions.add(promo);
                }
            }
            TimeLogger.endTimer('filterPromotions');
            return filteredPromotions;
        }
        
        // If not in cache, query and cache the result
        TimeLogger.startTimer('queryPromotions');
        promotions = [
            SELECT Id, Name, Product_Category__c, Region__c, Bonus_Rate__c, 
                   Start_Date__c, End_Date__c, Is_Active__c
            FROM Promotion__c
            WHERE Is_Active__c = true
        ];
        TimeLogger.endTimer('queryPromotions');
        
        // Cache all promotions
        TimeLogger.startTimer('cachePromotions');
        orgPartition.put(cacheKey, promotions, PROMOTIONS_CACHE_TTL);
        TimeLogger.endTimer('cachePromotions');
        
        // Filter the promotions based on the parameters
        TimeLogger.startTimer('filterPromotions');
        List<Promotion__c> filteredPromotions = new List<Promotion__c>();
        for (Promotion__c promo : promotions) {
            if ((promo.Region__c == region || promo.Region__c == 'Global') &&
                promo.Start_Date__c <= endDate &&
                promo.End_Date__c >= startDate) {
                filteredPromotions.add(promo);
            }
        }
        TimeLogger.endTimer('filterPromotions');
        
        return filteredPromotions;
    }
    
    /**
     * Get exchange rates for the period - CACHED VERSION
     * @param startDate The start date
     * @param endDate The end date
     * @return Map of currency pairs to exchange rates
     */
    private Map<String, Decimal> getExchangeRates(Date startDate, Date endDate) {
        // Try to get from cache first
        Cache.OrgPartition orgPartition = Cache.Org.getPartition(ORG_PARTITION_NAME);
        String cacheKey = EXCHANGE_RATES_KEY;
        
        Map<String, Decimal> rates = new Map<String, Decimal>();
        List<Exchange_Rate__c> exchangeRates;
        
        if (orgPartition.contains(cacheKey)) {
            TimeLogger.startTimer('getExchangeRatesFromCache');
            exchangeRates = (List<Exchange_Rate__c>)orgPartition.get(cacheKey);
            TimeLogger.endTimer('getExchangeRatesFromCache');
        } else {
            // If not in cache, query and cache the result
            TimeLogger.startTimer('queryExchangeRates');
            exchangeRates = [
                SELECT Id, From_Currency__c, To_Currency__c, Rate__c, Effective_Date__c
                FROM Exchange_Rate__c
                ORDER BY From_Currency__c, To_Currency__c, Effective_Date__c DESC
            ];
            TimeLogger.endTimer('queryExchangeRates');
            
            // Cache all exchange rates
            TimeLogger.startTimer('cacheExchangeRates');
            orgPartition.put(cacheKey, exchangeRates, RATES_CACHE_TTL);
            TimeLogger.endTimer('cacheExchangeRates');
        }
        
        // Filter and process the exchange rates
        TimeLogger.startTimer('processExchangeRates');
        Map<String, Exchange_Rate__c> latestRates = new Map<String, Exchange_Rate__c>();
        for (Exchange_Rate__c rate : exchangeRates) {
            if (rate.Effective_Date__c <= endDate) {
                String key = rate.From_Currency__c + '-' + rate.To_Currency__c;
                if (!latestRates.containsKey(key)) {
                    latestRates.put(key, rate);
                    rates.put(key, rate.Rate__c);
                }
            }
        }
        TimeLogger.endTimer('processExchangeRates');
        
        return rates;
    }
    
    /**
     * Get team data - CACHED VERSION
     * @param teamId The ID of the team
     * @return The team record
     */
    private Team__c getTeam(Id teamId) {
        // Try to get from cache first
        Cache.SessionPartition sessionPartition = Cache.Session.getPartition(SESSION_PARTITION_NAME);
        String cacheKey = TEAM_KEY_PREFIX + teamId;
        
        if (sessionPartition.contains(cacheKey)) {
            TimeLogger.startTimer('getTeamFromCache');
            Team__c team = (Team__c)sessionPartition.get(cacheKey);
            TimeLogger.endTimer('getTeamFromCache');
            return team;
        }
        
        // If not in cache, query and cache the result
        TimeLogger.startTimer('queryTeam');
        Team__c team = [
            SELECT Id, Name, Region__c, Quarter_Target__c, Year_Target__c,
                   Quarter_Achieved__c, Year_Achieved__c
            FROM Team__c
            WHERE Id = :teamId
        ];
        TimeLogger.endTimer('queryTeam');
        
        // Cache the team
        TimeLogger.startTimer('cacheTeam');
        sessionPartition.put(cacheKey, team, TEAM_CACHE_TTL);
        TimeLogger.endTimer('cacheTeam');
        
        return team;
    }
    
    /**
     * Process commission calculation
     * This method is the same as in the uncached version
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
     * This method is the same as in the uncached version
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
     * This method is the same as in the uncached version
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
     * This method is the same as in the uncached version
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
        List<Commission_Rules__c> commissionRules = getCommissionRules(
            salesRep.Region__c, 
            salesRep.Seniority_Level__c, 
            opp.CloseDate, 
            opp.CloseDate
        );
        TimeLogger.endTimer('getCommissionRulesForWhatIf');
        
        // Get promotions
        TimeLogger.startTimer('getPromotionsForWhatIf');
        List<Promotion__c> promotions = getPromotions(
            salesRep.Region__c, 
            opp.CloseDate, 
            opp.CloseDate
        );
        TimeLogger.endTimer('getPromotionsForWhatIf');
        
        // Get exchange rates
        TimeLogger.startTimer('getExchangeRatesForWhatIf');
        Map<String, Decimal> exchangeRates = getExchangeRates(opp.CloseDate, opp.CloseDate);
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