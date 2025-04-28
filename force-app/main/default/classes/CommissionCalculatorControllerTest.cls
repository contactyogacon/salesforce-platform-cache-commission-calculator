@isTest
public class CommissionCalculatorControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create team
        Team__c team = new Team__c(
            Name = 'Test Team',
            Region__c = 'North America',
            Quarter_Target__c = 1000000,
            Year_Target__c = 4000000,
            Quarter_Achieved__c = 1200000,
            Year_Achieved__c = 3000000
        );
        insert team;
        
        // Create user
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
        
        // Create sales rep
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
                Product_Category__c = 'Hardware',
                Region__c = 'North America',
                Bonus_Rate__c = 0.02,
                Start_Date__c = Date.newInstance(2023, 6, 1),
                End_Date__c = Date.newInstance(2023, 6, 30),
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
            )
        };
        insert exchangeRates;
        
        // Create products
        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Hardware Product', Family = 'Hardware', IsActive = true),
            new Product2(Name = 'Software Product', Family = 'Software', IsActive = true)
        };
        insert products;
        
        // Create pricebook entries
        Id standardPricebookId = Test.getStandardPricebookId();
        List<PricebookEntry> pricebookEntries = new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = products[0].Id, UnitPrice = 5000, IsActive = true),
            new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = products[1].Id, UnitPrice = 15000, IsActive = true)
        };
        insert pricebookEntries;
        
        // Create opportunities
        List<Opportunity> opportunities = new List<Opportunity>();
        for(Integer i = 1; i <= 3; i++) {
            opportunities.add(new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Closed Won',
                CloseDate = Date.newInstance(2023, 6, i),
                Amount = 20000 * i,
                OwnerId = u.Id,
                Pricebook2Id = standardPricebookId
            ));
        }
        insert opportunities;
        
        // Create opportunity line items
        List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
        for(Integer i = 0; i < 3; i++) {
            lineItems.add(new OpportunityLineItem(
                OpportunityId = opportunities[i].Id,
                PricebookEntryId = pricebookEntries[0].Id,
                Quantity = i + 1,
                UnitPrice = 5000
            ));
            lineItems.add(new OpportunityLineItem(
                OpportunityId = opportunities[i].Id,
                PricebookEntryId = pricebookEntries[1].Id,
                Quantity = i + 1,
                UnitPrice = 15000
            ));
        }
        insert lineItems;
        
        // Create a commission statement for testing getCommissionDetails
        Commission_Statement__c statement = new Commission_Statement__c(
            Sales_Rep__c = rep.Id,
            Period__c = '2023-06',
            Total_Sales__c = 50000,
            Base_Commission__c = 5000,
            Team_Bonus__c = 500,
            Promotion_Bonus__c = 1000,
            Total_Commission__c = 6500,
            Status__c = 'Draft',
            Calculation_Date__c = System.now()
        );
        insert statement;
        
        // Create commission details
        Commission_Detail__c detail = new Commission_Detail__c(
            Commission_Statement__c = statement.Id,
            Opportunity__c = opportunities[0].Id,
            Product__c = products[0].Id,
            Product_Category__c = 'Hardware',
            Sales_Amount__c = 5000,
            Commission_Rate__c = 0.05,
            Commission_Amount__c = 250,
            Promotion_Bonus__c = 100,
            Exchange_Rate__c = 1.0,
            Original_Currency__c = 'USD'
        );
        insert detail;
    }
    
    @isTest
    static void testCalculateCommission() {
        // Get the sales rep
        Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c LIMIT 1];
        
        Test.startTest();
        // Call the controller method
        Commission_Statement__c statement = CommissionCalculatorController.calculateCommission(rep.Id, '2023-06');
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, statement, 'Commission statement should not be null');
        System.assertEquals(rep.Id, statement.Sales_Rep__c, 'Sales rep should match');
        System.assertEquals('2023-06', statement.Period__c, 'Period should match');
    }
    
    @isTest
    static void testCalculateWhatIfCommission() {
        // Get an opportunity
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        // Call the controller method
        Decimal commission = CommissionCalculatorController.calculateWhatIfCommission(opp.Id);
        Test.stopTest();
        
        // Verify results
        System.assert(commission >= 0, 'Commission should be greater than or equal to zero');
    }
    
    @isTest
    static void testGetCommissionStatement() {
        // Get the sales rep
        Sales_Rep__c rep = [SELECT Id FROM Sales_Rep__c LIMIT 1];
        
        // First create a statement using the calculate method
        Test.startTest();
        Commission_Statement__c statement = CommissionCalculatorController.calculateCommission(rep.Id, '2023-06');
        
        // Then retrieve it using the get method
        Commission_Statement__c retrievedStatement = CommissionCalculatorController.getCommissionStatement(rep.Id, '2023-06');
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, retrievedStatement, 'Retrieved statement should not be null');
        System.assertEquals(rep.Id, retrievedStatement.Sales_Rep__c, 'Sales rep should match');
        System.assertEquals('2023-06', retrievedStatement.Period__c, 'Period should match');
    }
    
    @isTest
    static void testGetCommissionDetails() {
        // Get a commission statement
        Commission_Statement__c statement = [SELECT Id FROM Commission_Statement__c LIMIT 1];
        
        Test.startTest();
        // Call the controller method
        List<Commission_Detail__c> details = CommissionCalculatorController.getCommissionDetails(statement.Id);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(0, details.size(), 'Should have commission details');
    }
    
    @isTest
    static void testControllerExceptions() {
        // Test exception handling in calculateCommission
        Test.startTest();
        try {
            // Pass an invalid ID to trigger an exception
            CommissionCalculatorController.calculateCommission(null, '2023-06');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Expected exception
            System.assert(true, 'Exception was caught as expected');
        }
        
        // Test exception handling in calculateWhatIfCommission
        try {
            // Pass an invalid ID to trigger an exception
            CommissionCalculatorController.calculateWhatIfCommission(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Expected exception
            System.assert(true, 'Exception was caught as expected');
        }
        
        // Test exception handling in getCommissionStatement
        try {
            // Pass an invalid ID to trigger an exception
            CommissionCalculatorController.getCommissionStatement(null, null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Expected exception
            System.assert(true, 'Exception was caught as expected');
        }
        
        Test.stopTest();
    }
}
