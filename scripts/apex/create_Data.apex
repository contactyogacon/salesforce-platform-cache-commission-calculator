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

// Create a user (or use an existing one)
User u;
try {
    u = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
} catch(Exception e) {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    u = new User(
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
}

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

// Create commission rules - create more for better testing
List<Commission_Rules__c> rules = new List<Commission_Rules__c>();

// Hardware rules with different tiers
rules.add(new Commission_Rules__c(
    Name = 'Hardware Rule - Tier 1',
    Product_Category__c = 'Hardware',
    Region__c = 'North America',
    Seniority_Level__c = 'Senior',
    Start_Date__c = Date.newInstance(2023, 1, 1),
    End_Date__c = Date.newInstance(2025, 12, 31),
    Min_Amount__c = 0,
    Max_Amount__c = 10000,
    Commission_Rate__c = 0.05,
    Is_Active__c = true
));

rules.add(new Commission_Rules__c(
    Name = 'Hardware Rule - Tier 2',
    Product_Category__c = 'Hardware',
    Region__c = 'North America',
    Seniority_Level__c = 'Senior',
    Start_Date__c = Date.newInstance(2023, 1, 1),
    End_Date__c = Date.newInstance(2025, 12, 31),
    Min_Amount__c = 10000,
    Max_Amount__c = 50000,
    Commission_Rate__c = 0.07,
    Is_Active__c = true
));

rules.add(new Commission_Rules__c(
    Name = 'Hardware Rule - Tier 3',
    Product_Category__c = 'Hardware',
    Region__c = 'North America',
    Seniority_Level__c = 'Senior',
    Start_Date__c = Date.newInstance(2023, 1, 1),
    End_Date__c = Date.newInstance(2025, 12, 31),
    Min_Amount__c = 50000,
    Max_Amount__c = null,
    Commission_Rate__c = 0.09,
    Is_Active__c = true
));

// Software rules with different tiers
rules.add(new Commission_Rules__c(
    Name = 'Software Rule - Tier 1',
    Product_Category__c = 'Software',
    Region__c = 'North America',
    Seniority_Level__c = 'Senior',
    Start_Date__c = Date.newInstance(2023, 1, 1),
    End_Date__c = Date.newInstance(2025, 12, 31),
    Min_Amount__c = 0,
    Max_Amount__c = 10000,
    Commission_Rate__c = 0.10,
    Is_Active__c = true
));

rules.add(new Commission_Rules__c(
    Name = 'Software Rule - Tier 2',
    Product_Category__c = 'Software',
    Region__c = 'North America',
    Seniority_Level__c = 'Senior',
    Start_Date__c = Date.newInstance(2023, 1, 1),
    End_Date__c = Date.newInstance(2025, 12, 31),
    Min_Amount__c = 10000,
    Max_Amount__c = 50000,
    Commission_Rate__c = 0.12,
    Is_Active__c = true
));

rules.add(new Commission_Rules__c(
    Name = 'Software Rule - Tier 3',
    Product_Category__c = 'Software',
    Region__c = 'North America',
    Seniority_Level__c = 'Senior',
    Start_Date__c = Date.newInstance(2023, 1, 1),
    End_Date__c = Date.newInstance(2025, 12, 31),
    Min_Amount__c = 50000,
    Max_Amount__c = null,
    Commission_Rate__c = 0.15,
    Is_Active__c = true
));

// Services rules
rules.add(new Commission_Rules__c(
    Name = 'Services Rule',
    Product_Category__c = 'Services',
    Region__c = 'North America',
    Seniority_Level__c = 'Senior',
    Start_Date__c = Date.newInstance(2023, 1, 1),
    End_Date__c = Date.newInstance(2025, 12, 31),
    Min_Amount__c = 0,
    Max_Amount__c = null,
    Commission_Rate__c = 0.20,
    Is_Active__c = true
));

// Subscription rules
rules.add(new Commission_Rules__c(
    Name = 'Subscription Rule',
    Product_Category__c = 'Subscription',
    Region__c = 'North America',
    Seniority_Level__c = 'Senior',
    Start_Date__c = Date.newInstance(2023, 1, 1),
    End_Date__c = Date.newInstance(2025, 12, 31),
    Min_Amount__c = 0,
    Max_Amount__c = null,
    Commission_Rate__c = 0.08,
    Is_Active__c = true
));

insert rules;

// Create promotions
List<Promotion__c> promotions = new List<Promotion__c>{
    new Promotion__c(
        Name = 'Hardware Promotion',
        Product_Category__c = 'Hardware',
        Region__c = 'North America',
        Bonus_Rate__c = 0.02,
        Start_Date__c = Date.newInstance(2025, 1, 1),
        End_Date__c = Date.newInstance(2025, 12, 31),
        Is_Active__c = true
    ),
    new Promotion__c(
        Name = 'Software Promotion',
        Product_Category__c = 'Software',
        Region__c = 'North America',
        Bonus_Rate__c = 0.03,
        Start_Date__c = Date.newInstance(2025, 1, 1),
        End_Date__c = Date.newInstance(2025, 12, 31),
        Is_Active__c = true
    ),
    new Promotion__c(
        Name = 'Q2 Special',
        Product_Category__c = 'All',
        Region__c = 'North America',
        Bonus_Rate__c = 0.01,
        Start_Date__c = Date.newInstance(2025, 4, 1),
        End_Date__c = Date.newInstance(2025, 6, 30),
        Is_Active__c = true
    )
};
insert promotions;

// Create exchange rates
List<Exchange_Rate__c> exchangeRates = new List<Exchange_Rate__c>{
    new Exchange_Rate__c(
        Name = 'EUR to USD 2025-01-01',
        From_Currency__c = 'EUR',
        To_Currency__c = 'USD',
        Rate__c = 1.1,
        Effective_Date__c = Date.newInstance(2025, 1, 1)
    ),
    new Exchange_Rate__c(
        Name = 'EUR to USD 2025-04-01',
        From_Currency__c = 'EUR',
        To_Currency__c = 'USD',
        Rate__c = 1.12,
        Effective_Date__c = Date.newInstance(2025, 4, 1)
    ),
    new Exchange_Rate__c(
        Name = 'GBP to USD 2025-01-01',
        From_Currency__c = 'GBP',
        To_Currency__c = 'USD',
        Rate__c = 1.3,
        Effective_Date__c = Date.newInstance(2025, 1, 1)
    ),
    new Exchange_Rate__c(
        Name = 'GBP to USD 2025-04-01',
        From_Currency__c = 'GBP',
        To_Currency__c = 'USD',
        Rate__c = 1.32,
        Effective_Date__c = Date.newInstance(2025, 4, 1)
    )
};
insert exchangeRates;

// Create products
List<Product2> products = new List<Product2>{
    new Product2(Name = 'Server Hardware', Family = 'Hardware', IsActive = true),
    new Product2(Name = 'Networking Equipment', Family = 'Hardware', IsActive = true),
    new Product2(Name = 'Enterprise Software', Family = 'Software', IsActive = true),
    new Product2(Name = 'Mobile App License', Family = 'Software', IsActive = true),
    new Product2(Name = 'Implementation Services', Family = 'Services', IsActive = true),
    new Product2(Name = 'Cloud Subscription', Family = 'Subscription', IsActive = true)
};
insert products;

// Create pricebook entries
Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();

for(Product2 prod : products) {
    Decimal price;
    if(prod.Family == 'Hardware') {
        price = 5000;
    } else if(prod.Family == 'Software') {
        price = 15000;
    } else if(prod.Family == 'Services') {
        price = 10000;
    } else {
        price = 2000;
    }
    
    pricebookEntries.add(new PricebookEntry(
        Pricebook2Id = standardPricebookId,
        Product2Id = prod.Id,
        UnitPrice = price,
        IsActive = true
    ));
}
insert pricebookEntries;

// Create opportunities - create 20 for better volume testing
List<Opportunity> opportunities = new List<Opportunity>();
for(Integer i = 1; i <= 20; i++) {
    Date closeDate = Date.newInstance(2025, (Math.mod(i, 4) + 1), i);
    opportunities.add(new Opportunity(
        Name = 'Opportunity ' + i,
        StageName = 'Closed Won',
        CloseDate = closeDate,
        Amount = 10000 * i,
        OwnerId = u.Id,
        Pricebook2Id = standardPricebookId
    ));
}
insert opportunities;

// Create opportunity line items - multiple per opportunity
List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();

// Map to hold pricebook entries by product ID
Map<Id, PricebookEntry> pbeByProductId = new Map<Id, PricebookEntry>();
for(PricebookEntry pbe : pricebookEntries) {
    pbeByProductId.put(pbe.Product2Id, pbe);
}

// Create line items for each opportunity
for(Integer i = 0; i < opportunities.size(); i++) {
    // Add different products to each opportunity
    for(Integer j = 0; j < products.size(); j++) {
        // Only add some products to each opportunity to create variety
        if(Math.mod(i + j, 3) == 0) {
            Product2 prod = products[j];
            PricebookEntry pbe = pbeByProductId.get(prod.Id);
            
            Integer quantity = Math.mod(i, 5) + 1;
            lineItems.add(new OpportunityLineItem(
                OpportunityId = opportunities[i].Id,
                PricebookEntryId = pbe.Id,
                Quantity = quantity,
                UnitPrice = pbe.UnitPrice
            ));
        }
    }
}
insert lineItems;

System.debug('Test data creation complete!');
System.debug('Created ' + team.Id + ' team');
System.debug('Created ' + rep.Id + ' sales rep');
System.debug('Created ' + rules.size() + ' commission rules');
System.debug('Created ' + promotions.size() + ' promotions');
System.debug('Created ' + exchangeRates.size() + ' exchange rates');
System.debug('Created ' + products.size() + ' products');
System.debug('Created ' + pricebookEntries.size() + ' pricebook entries');
System.debug('Created ' + opportunities.size() + ' opportunities');
System.debug('Created ' + lineItems.size() + ' opportunity line items');
