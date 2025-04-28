// Check if cache keys exist
Boolean hasCommissionRules = Cache.Org.getPartition('local.CommissionCache').contains('commissionrules');
Boolean hasPromotions = Cache.Org.getPartition('local.CommissionCache').contains('promotions');
Boolean hasExchangeRates = Cache.Org.getPartition('local.CommissionCache').contains('exchangerates');
Boolean hasTeam = Cache.Org.getPartition('local.CommissionCache').contains('team');


// Print cache existence status
System.debug('Commission Rules in cache: ' + hasCommissionRules);
System.debug('Promotions in cache: ' + hasPromotions);
System.debug('Exchange Rates in cache: ' + hasExchangeRates);
System.debug('Team in cache: ' + hasTeam);

// Clear specific cache keys
if (hasCommissionRules) {
    Cache.Org.getPartition('local.CommissionCache').remove('commissionrules');
    System.debug('Removed Commission Rules from cache');
}

if (hasPromotions) {
    Cache.Org.getPartition('local.CommissionCache').remove('promotions');
    System.debug('Removed Promotions from cache');
}

if (hasExchangeRates) {
    Cache.Org.getPartition('local.CommissionCache').remove('exchangerates');
    System.debug('Removed Exchange Rates from cache');
}

if (hasTeam) {
    Cache.Org.getPartition('local.CommissionCache').remove('team');
    System.debug('Removed Team from cache');
}


