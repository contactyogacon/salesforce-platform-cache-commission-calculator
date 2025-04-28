// Get the sales rep
Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c WHERE Name = 'Test Rep' LIMIT 1];

// Run cached version again to see the full benefit of caching
String period = '2025-04';
System.debug('*** CACHED VERSION - SECOND RUN ***');
CachedCommissionCalculatorService cachedService = new CachedCommissionCalculatorService();
Commission_Statement__c cachedStatement = cachedService.calculateCommission(rep.Id, period);
