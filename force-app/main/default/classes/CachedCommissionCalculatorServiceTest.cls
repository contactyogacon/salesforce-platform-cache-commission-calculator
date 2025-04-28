/**
 * Test class for cached commission calculator
 */
@isTest
private class CachedCommissionCalculatorServiceTest {
    
    // Setup a test cache partition
    private static final String TEST_PARTITION = 'local.CommissionCache';
    
    @testSetup
    static void setupTestData() {
        // Create test data
        
        // Create a team
        Team__c team = new Team__c(
            Name = 'Test Team',
            Region__c = 'North America',
            Quarter_Target__c = 1000000,
            Year_Target__c = 4000000,
            Quarter_Achieved__c = 1200000,
            Year_Achieved__c = 3000000
        );
        insert team;
        
        // Create a user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            ProfileId = p.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert u;
        
        // Create a sales rep
        Sales_Rep__c rep = new Sales_Rep__c(
            Name = 'Test Rep',
            User__c = u.Id,
            Region__c = 'North America',
            Seniority_Level__c = 'Senior',
            Team__c = team.Id,
            YTD_Sales__c = 1000000,
            Quarter_Sales__c = 300000
        );
        insert rep;
        
        // Create commission rules
        List<Commission_Rules__c> rules = new List<Commission_Rules__c>{
            new Commission_Rules__c(
                Name = 'Hardware Rule 1',
                Product_Category__c = 'Hardware',
                Region__c = 'North America',
                Seniority_Level__c = 'Senior',
                Start_Date__c = Date.newInstance(2023, 1, 1),
                End_Date__c = Date.newInstance(2025, 12, 31),
                Min_Amount__c = 0,
                Max_Amount__c = 10000,
                Commission_Rate__c = 0.05,
                Is_Active__c = true
            ),
            new Commission_Rules__c(
                Name = 'Hardware Rule 2',
                Product_Category__c = 'Hardware',
                Region__c = 'North America',
                Seniority_Level__c = 'Senior',
                Start_Date__c = Date.newInstance(2023, 1, 1),
                End_Date__c = Date.newInstance(2025, 12, 31),
                Min_Amount__c = 10000,
                Max_Amount__c = null,
                Commission_Rate__c = 0.08,
                Is_Active__c = true
            ),
            new Commission_Rules__c(
                Name = 'Software Rule',
                Product_Category__c = 'Software',
                Region__c = 'North America',
                Seniority_Level__c = 'Senior',
                Start_Date__c = Date.newInstance(2023, 1, 1),
                End_Date__c = Date.newInstance(2025, 12, 31),
                Min_Amount__c = 0,
                Max_Amount__c = null,
                Commission_Rate__c = 0.10,
                Is_Active__c = true
            )
        };
        insert rules;
        
        // Create promotions
        List<Promotion__c> promotions = new List<Promotion__c>{
            new Promotion__c(
                Name = 'Hardware Promotion',
                Start_Date__c = Date.newInstance(2023, 6, 1),
                End_Date__c = Date.newInstance(2025, 6, 30),
                Product_Category__c = 'Hardware',
                Region__c = 'North America',
                Bonus_Rate__c = 0.02,
                Is_Active__c = true
            ),
            new Promotion__c(
                Name = 'Software Promotion',
                Start_Date__c = Date.newInstance(2023, 6, 1),
                End_Date__c = Date.newInstance(2025, 6, 30),
                Product_Category__c = 'Software',
                Region__c = 'North America',
                Bonus_Rate__c = 0.03,
                Is_Active__c = true
            )
        };
        insert promotions;
        
        // Create exchange rates
        List<Exchange_Rate__c> exchangeRates = new List<Exchange_Rate__c>{
            new Exchange_Rate__c(
                Name = 'EUR to USD 2023-06-01',
                From_Currency__c = 'EUR',
                To_Currency__c = 'USD',
                Rate__c = 1.1,
                Effective_Date__c = Date.newInstance(2023, 6, 1)
            ),
            new Exchange_Rate__c(
                Name = 'GBP to USD 2023-06-01',
                From_Currency__c = 'GBP',
                To_Currency__c = 'USD',
                Rate__c = 1.3,
                Effective_Date__c = Date.newInstance(2023, 6, 1)
            )
        };
        insert exchangeRates;
        
        // Create products
        List<Product2> products = new List<Product2>{
            new Product2(
                Name = 'Hardware Product',
                Family = 'Hardware',
                IsActive = true
            ),
            new Product2(
                Name = 'Software Product',
                Family = 'Software',
                IsActive = true
            )
        };
        insert products;
        
        // Create standard price book entry
        Id standardPricebookId = Test.getStandardPricebookId();
        
        List<PricebookEntry> pricebookEntries = new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = products[0].Id,
                UnitPrice = 5000,
                IsActive = true
            ),
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = products[1].Id,
                UnitPrice = 15000,
                IsActive = true
            )
        };
        insert pricebookEntries;
        
        // Create opportunities
        List<Opportunity> opportunities = new List<Opportunity>();
        
        // Create opportunities for June 2023
        for(Integer i = 1; i <= 5; i++) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Closed Won',
                CloseDate = Date.newInstance(2023, 6, i),
                Amount = 20000 * i,
                OwnerId = u.Id,
                Pricebook2Id = standardPricebookId
            );
            opportunities.add(opp);
        }
        
        insert opportunities;
        
        // Create opportunity line items
        List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
        
        for(Integer i = 0; i < 5; i++) {
            // Add hardware product
            OpportunityLineItem hardwareItem = new OpportunityLineItem(
                OpportunityId = opportunities[i].Id,
                PricebookEntryId = pricebookEntries[0].Id,
                Quantity = i + 1,
                UnitPrice = 5000
            );
            lineItems.add(hardwareItem);
            
            // Add software product
            OpportunityLineItem softwareItem = new OpportunityLineItem(
                OpportunityId = opportunities[i].Id,
                PricebookEntryId = pricebookEntries[1].Id,
                Quantity = i + 1,
                UnitPrice = 15000
            );
            lineItems.add(softwareItem);
        }
        
        insert lineItems;
    }
    
    @isTest
    static void testCalculateCommission() {
        // Get the sales rep
        Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c LIMIT 1];
        
        Test.startTest();
        
        // First run - should populate cache
        CachedCommissionCalculatorService service = new CachedCommissionCalculatorService();
        Commission_Statement__c statement1 = service.calculateCommission(rep.Id, '2023-06');
        
        // Verify first run results
        System.assertNotEquals(null, statement1, 'Commission statement should not be null');
        System.assertEquals('2023-06', statement1.Period__c, 'Period should match');
        System.assertEquals(rep.Id, statement1.Sales_Rep__c, 'Sales rep should match');
        System.assertNotEquals(0, statement1.Total_Sales__c, 'Total sales should not be zero');
        System.assertNotEquals(0, statement1.Base_Commission__c, 'Base commission should not be zero');
        System.assertNotEquals(0, statement1.Total_Commission__c, 'Total commission should not be zero');
        
        // Second run - should use cache
        Commission_Statement__c statement2 = service.calculateCommission(rep.Id, '2023-06');
        
        Test.stopTest();
        
        // Verify second run results
        System.assertNotEquals(null, statement2, 'Second commission statement should not be null');
        System.assertEquals('2023-06', statement2.Period__c, 'Second period should match');
        System.assertEquals(rep.Id, statement2.Sales_Rep__c, 'Second sales rep should match');
        
        // The values should be the same between runs
        System.assertEquals(statement1.Total_Sales__c, statement2.Total_Sales__c, 'Total sales should match between runs');
        System.assertEquals(statement1.Base_Commission__c, statement2.Base_Commission__c, 'Base commission should match between runs');
        System.assertEquals(statement1.Total_Commission__c, statement2.Total_Commission__c, 'Total commission should match between runs');
    }
    
    @isTest
    static void testCalculateWhatIfCommission() {
        // Get an opportunity
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        
        // First run - should populate cache
        CachedCommissionCalculatorService service = new CachedCommissionCalculatorService();
        Decimal commission1 = service.calculateWhatIfCommission(opp.Id);
        
        // Second run - should use cache
        Decimal commission2 = service.calculateWhatIfCommission(opp.Id);
        
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(0, commission1, 'Commission should not be zero');
        System.assertEquals(commission1, commission2, 'Commission should be the same between runs');
    }
    
    @isTest
    static void testCacheBehavior() {
        // This test verifies that the cache is being used correctly
        
        // Get the sales rep
        Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c LIMIT 1];
        
        Test.startTest();
        
        // First run - should populate cache
        CachedCommissionCalculatorService service = new CachedCommissionCalculatorService();
        service.calculateCommission(rep.Id, '2023-06');
        
        // Now add a new commission rule that would affect the calculation
        Commission_Rules__c newRule = new Commission_Rules__c(
            Name = 'New Hardware Rule',
            Product_Category__c = 'Hardware',
            Region__c = 'North America',
            Seniority_Level__c = 'Senior',
            Start_Date__c = Date.newInstance(2023, 1, 1),
            End_Date__c = Date.newInstance(2025, 12, 31),
            Min_Amount__c = 0,
            Max_Amount__c = 5000,
            Commission_Rate__c = 0.15, // Higher rate
            Is_Active__c = true
        );
        insert newRule;
        
        // Second run - should use cached rules, so the new rule won't affect the calculation
        Commission_Statement__c statement = service.calculateCommission(rep.Id, '2023-06');
        
        Test.stopTest();
        
        // Verify that the cache was used (new rule shouldn't affect calculation)
        List<Commission_Detail__c> details = [
            SELECT Id, Commission_Rate__c
            FROM Commission_Detail__c
            WHERE Commission_Statement__c = :statement.Id
            AND Product_Category__c = 'Hardware'
            AND Sales_Amount__c <= 5000
            LIMIT 1
        ];
        
        if (!details.isEmpty()) {
            // If we have a detail in this range, it should use the old rate, not the new 0.15 rate
            System.assertNotEquals(0.15, details[0].Commission_Rate__c, 'Should use cached commission rule, not the new one');
        }
    }
    
    @isTest
    static void testCompareWithUncachedService() {
        // This test compares results between cached and uncached services
        
        // Get the sales rep
        Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c LIMIT 1];
        
        Test.startTest();
        
        // Calculate with uncached service
        CommissionCalculatorService uncachedService = new CommissionCalculatorService();
        Commission_Statement__c uncachedStatement = uncachedService.calculateCommission(rep.Id, '2023-06');
        
        // Calculate with cached service
        CachedCommissionCalculatorService cachedService = new CachedCommissionCalculatorService();
        
        Commission_Statement__c cachedStatement = cachedService.calculateCommission(rep.Id, '2023-06');
        Test.stopTest();
        
        // Verify that both services produce the same results
        System.assertEquals(uncachedStatement.Total_Sales__c, cachedStatement.Total_Sales__c, 'Total sales should match between services');
        System.assertEquals(uncachedStatement.Base_Commission__c, cachedStatement.Base_Commission__c, 'Base commission should match between services');
        System.assertEquals(uncachedStatement.Team_Bonus__c, cachedStatement.Team_Bonus__c, 'Team bonus should match between services');
        System.assertEquals(uncachedStatement.Promotion_Bonus__c, cachedStatement.Promotion_Bonus__c, 'Promotion bonus should match between services');
        System.assertEquals(uncachedStatement.Total_Commission__c, cachedStatement.Total_Commission__c, 'Total commission should match between services');
    }
}
