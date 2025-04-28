// Get the sales rep
Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c WHERE Name = 'Test Rep' LIMIT 1];

// Calculate commission using cached service
String period = '2025-04';
System.debug('*** CACHED VERSION - FIRST RUN ***');
CachedCommissionCalculatorService cachedService = new CachedCommissionCalculatorService();
Commission_Statement__c cachedStatement = cachedService.calculateCommission(rep.Id, period);

