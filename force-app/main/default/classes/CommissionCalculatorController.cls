/**
 * Controller for commission calculation
 */
public with sharing class CommissionCalculatorController {
    
    /**
     * Calculate commission for a sales rep
     * @param salesRepId The ID of the sales rep
     * @param period The period in format YYYY-MM
     * @return The calculated commission statement
     */
    @AuraEnabled
    public static Commission_Statement__c calculateCommission(Id salesRepId, String period) {
        try {
            CommissionCalculatorService service = new CommissionCalculatorService();
            return service.calculateCommission(salesRepId, period);
        } catch (Exception e) {
            throw new AuraHandledException('Error calculating commission: ' + e.getMessage());
        }
    }
    
    /**
     * Calculate what-if commission for an opportunity
     * @param opportunityId The ID of the opportunity
     * @return The calculated commission amount
     */
    @AuraEnabled
    public static Decimal calculateWhatIfCommission(Id opportunityId) {
        try {
            CommissionCalculatorService service = new CommissionCalculatorService();
            return service.calculateWhatIfCommission(opportunityId);
        } catch (Exception e) {
            throw new AuraHandledException('Error calculating what-if commission: ' + e.getMessage());
        }
    }
    
    /**
     * Get commission statement for a sales rep
     * @param salesRepId The ID of the sales rep
     * @param period The period in format YYYY-MM
     * @return The commission statement
     */
    @AuraEnabled(cacheable=true)
    public static Commission_Statement__c getCommissionStatement(Id salesRepId, String period) {
        try {
            return [
                SELECT Id, Name, Sales_Rep__c, Period__c, Total_Sales__c, Base_Commission__c,
                       Team_Bonus__c, Promotion_Bonus__c, Total_Commission__c, Status__c,
                       Calculation_Date__c
                FROM Commission_Statement__c
                WHERE Sales_Rep__c = :salesRepId
                AND Period__c = :period
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error getting commission statement: ' + e.getMessage());
        }
    }
    
    /**
     * Get commission details for a statement
     * @param statementId The ID of the statement
     * @return List of commission details
     */
    @AuraEnabled(cacheable=true)
    public static List<Commission_Detail__c> getCommissionDetails(Id statementId) {
        try {
            return [
                SELECT Id, Opportunity__c, Opportunity__r.Name, Product__c, Product__r.Name,
                       Product_Category__c, Sales_Amount__c, Commission_Rate__c, Commission_Amount__c,
                       Promotion_Bonus__c, Exchange_Rate__c, Original_Currency__c
                FROM Commission_Detail__c
                WHERE Commission_Statement__c = :statementId
                ORDER BY Product_Category__c, Sales_Amount__c DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error getting commission details: ' + e.getMessage());
        }
    }
}
