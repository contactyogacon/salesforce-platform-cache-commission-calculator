// Get the sales rep
Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c WHERE Name = 'Test Rep' LIMIT 1];

// Calculate commission using uncached service
String period = '2025-04';
System.debug('*** UNCACHED VERSION ***');
CommissionCalculatorService uncachedService = new CommissionCalculatorService();
Commission_Statement__c uncachedStatement = uncachedService.calculateCommission(rep.Id, period);


