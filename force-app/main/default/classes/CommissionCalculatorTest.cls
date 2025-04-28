/**
 * Test class for commission calculator
 */
@isTest
private class CommissionCalculatorTest {
    
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
            Username = 'testuser@example.com' + System.currentTimeMillis(),
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
                End_Date__c = Date.newInstance(2023, 12, 31),
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
                End_Date__c = Date.newInstance(2023, 12, 31),
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
                End_Date__c = Date.newInstance(2023, 12, 31),
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
                End_Date__c = Date.newInstance(2023, 6, 30),
                Product_Category__c = 'Hardware',
                Region__c = 'North America',
                Bonus_Rate__c = 0.02,
                Is_Active__c = true
            ),
            new Promotion__c(
                Name = 'Software Promotion',
                Start_Date__c = Date.newInstance(2023, 6, 1),
                End_Date__c = Date.newInstance(2023, 6, 30),
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
                // Remove TotalPrice - Salesforce will calculate it automatically
            );
            lineItems.add(hardwareItem);
            
            // Add software product
            OpportunityLineItem softwareItem = new OpportunityLineItem(
                OpportunityId = opportunities[i].Id,
                PricebookEntryId = pricebookEntries[1].Id,
                Quantity = i + 1,
                UnitPrice = 15000
                // Remove TotalPrice - Salesforce will calculate it automatically
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
        
        // Calculate commission
        CommissionCalculatorService service = new CommissionCalculatorService();
        Commission_Statement__c statement = service.calculateCommission(rep.Id, '2023-06');
        
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, statement, 'Commission statement should not be null');
        System.assertEquals('2023-06', statement.Period__c, 'Period should match');
        System.assertEquals(rep.Id, statement.Sales_Rep__c, 'Sales rep should match');
        System.assertNotEquals(0, statement.Total_Sales__c, 'Total sales should not be zero');
        System.assertNotEquals(0, statement.Base_Commission__c, 'Base commission should not be zero');
        System.assertNotEquals(0, statement.Total_Commission__c, 'Total commission should not be zero');
        
        // Verify commission details
        List<Commission_Detail__c> details = [
            SELECT Id, Product_Category__c, Sales_Amount__c, Commission_Rate__c, Commission_Amount__c
            FROM Commission_Detail__c
            WHERE Commission_Statement__c = :statement.Id
        ];
        
        System.assertNotEquals(0, details.size(), 'Should have commission details');
        
        // Verify hardware and software products are included
        Set<String> categories = new Set<String>();
        for(Commission_Detail__c detail : details) {
            categories.add(detail.Product_Category__c);
        }
        
        System.assert(categories.contains('Hardware'), 'Should include Hardware category');
        System.assert(categories.contains('Software'), 'Should include Software category');
    }
    
    @isTest
    static void testCalculateWhatIfCommission() {
        // Get an opportunity
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        
        // Calculate what-if commission
        CommissionCalculatorService service = new CommissionCalculatorService();
        Decimal commission = service.calculateWhatIfCommission(opp.Id);
        
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(0, commission, 'Commission should not be zero');
    }
    
    @isTest
    static void testController() {
        // Get the sales rep
        Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c LIMIT 1];
        
        Test.startTest();
        
        // Calculate commission
        Commission_Statement__c statement = CommissionCalculatorController.calculateCommission(rep.Id, '2023-06');
        
        // Get commission statement
        Commission_Statement__c retrievedStatement = CommissionCalculatorController.getCommissionStatement(rep.Id, '2023-06');
        
        // Get commission details
        List<Commission_Detail__c> details = CommissionCalculatorController.getCommissionDetails(statement.Id);
        
        // Get an opportunity
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Calculate what-if commission
        Decimal commission = CommissionCalculatorController.calculateWhatIfCommission(opp.Id);
        
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, statement, 'Commission statement should not be null');
        System.assertNotEquals(null, retrievedStatement, 'Retrieved statement should not be null');
        System.assertEquals(statement.Id, retrievedStatement.Id, 'Statement IDs should match');
        System.assertNotEquals(0, details.size(), 'Should have commission details');
        System.assertNotEquals(0, commission, 'Commission should not be zero');
    }
}
