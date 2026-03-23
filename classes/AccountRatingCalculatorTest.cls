/**
 * @description Test class for AccountRatingCalculator
 * @author ACME Corporation
 * @date 2026-03-19
 */
@isTest
private class AccountRatingCalculatorTest {
    
    /**
     * @description Test data setup
     */
    @testSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();
        
        // Hot Account - High revenue, high employees, many opportunities
        Account hotAccount = new Account(
            Name = 'Hot Test Account',
            AnnualRevenue = 15000000,
            NumberOfEmployees = 1500
        );
        accounts.add(hotAccount);
        
        // Warm Account - Medium revenue, medium employees, some opportunities
        Account warmAccount = new Account(
            Name = 'Warm Test Account',
            AnnualRevenue = 6000000,
            NumberOfEmployees = 600
        );
        accounts.add(warmAccount);
        
        // Cold Account - Low revenue, low employees, few opportunities
        Account coldAccount = new Account(
            Name = 'Cold Test Account',
            AnnualRevenue = 500000,
            NumberOfEmployees = 50
        );
        accounts.add(coldAccount);
        
        // Zero values account
        Account zeroAccount = new Account(
            Name = 'Zero Test Account',
            AnnualRevenue = 0,
            NumberOfEmployees = 0
        );
        accounts.add(zeroAccount);
        
        // Null values account
        Account nullAccount = new Account(
            Name = 'Null Test Account'
        );
        accounts.add(nullAccount);
        
        insert accounts;
        
        // Create opportunities for hot account
        List<Opportunity> hotOpps = new List<Opportunity>();
        for (Integer i = 0; i < 12; i++) {
            hotOpps.add(new Opportunity(
                Name = 'Hot Opp ' + i,
                AccountId = hotAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        
        // Create opportunities for warm account
        List<Opportunity> warmOpps = new List<Opportunity>();
        for (Integer i = 0; i < 6; i++) {
            warmOpps.add(new Opportunity(
                Name = 'Warm Opp ' + i,
                AccountId = warmAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        
        // Create one opportunity for cold account
        List<Opportunity> coldOpps = new List<Opportunity>();
        coldOpps.add(new Opportunity(
            Name = 'Cold Opp',
            AccountId = coldAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        ));
        
        List<Opportunity> allOpps = new List<Opportunity>();
        allOpps.addAll(hotOpps);
        allOpps.addAll(warmOpps);
        allOpps.addAll(coldOpps);
        insert allOpps;
    }
    
    /**
     * @description Test hot rating calculation
     */
    @isTest
    static void testHotRatingCalculation() {
        Account hotAccount = [SELECT Id FROM Account WHERE Name = 'Hot Test Account' LIMIT 1];
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator.calculateAccountRating(hotAccount.Id);
            System.assertEquals('Hot', rating,
                'Account should be rated as Hot');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test warm rating calculation
     */
    @isTest
    static void testWarmRatingCalculation() {
        Account warmAccount = [SELECT Id FROM Account WHERE Name = 'Warm Test Account' LIMIT 1];
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator.calculateAccountRating(warmAccount.Id);
            System.assertEquals('Warm', rating,
                'Account should be rated as Warm');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test cold rating calculation
     */
    @isTest
    static void testColdRatingCalculation() {
        Account coldAccount = [SELECT Id FROM Account WHERE Name = 'Cold Test Account' LIMIT 1];
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator.calculateAccountRating(coldAccount.Id);
            System.assertEquals('Cold', rating,
                'Account should be rated as Cold');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test zero values account
     */
    @isTest
    static void testZeroValuesAccount() {
        Account zeroAccount = [SELECT Id FROM Account WHERE Name = 'Zero Test Account' LIMIT 1];
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator.calculateAccountRating(zeroAccount.Id);
            System.assertEquals('Cold', rating,
                'Account with zero values should be rated as Cold');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test null values account
     */
    @isTest
    static void testNullValuesAccount() {
        Account nullAccount = [SELECT Id FROM Account WHERE Name = 'Null Test Account' LIMIT 1];
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator.calculateAccountRating(nullAccount.Id);
            System.assertEquals('Cold', rating,
                'Account with null values should be rated as Cold');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test bulk rating calculation
     */
    @isTest
    static void testBulkRatingCalculation() {
        List<Account> accounts = [SELECT Id, Name FROM Account];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Map<Id, String> ratings = AccountRatingCalculator.calculateAccountRatings(accountIds);
            
            System.assertEquals(5, ratings.size(),
                'Should calculate ratings for all accounts');
            System.assert(ratings.values().contains('Hot'),
                'Should have at least one Hot rating');
            System.assert(ratings.values().contains('Warm'),
                'Should have at least one Warm rating');
            System.assert(ratings.values().contains('Cold'),
                'Should have at least one Cold rating');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test update account ratings
     */
    @isTest
    static void testUpdateAccountRatings() {
        List<Account> accounts = [SELECT Id FROM Account];
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            AccountRatingCalculator.updateAccountRatings(accountIds);
        }
        Test.stopTest();
        
        List<Account> updatedAccounts = [SELECT Id, Name, Rating FROM Account];
        for (Account acc : updatedAccounts) {
            System.assertNotEquals(null, acc.Rating,
                'Rating should be updated for account: ' + acc.Name);
        }
    }
    
    /**
     * @description Test null account ID exception
     */
    @isTest
    static void testNullAccountIdException() {
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            try {
                AccountRatingCalculator.calculateAccountRating(null);
                System.assert(false,
                    'Should throw exception for null account ID');
            } catch (AccountRatingCalculator.AccountRatingException e) {
                System.assert(e.getMessage().contains('cannot be null'),
                    'Exception message should mention null ID');
            }
        }
        Test.stopTest();
    }
    
    /**
     * @description Test invalid account ID exception
     */
    @isTest
    static void testInvalidAccountIdException() {
        // Generate a non-existent account ID dynamically
        String keyPrefix = Account.SObjectType.getDescribe().getKeyPrefix();
        Id fakeId = Id.valueOf(keyPrefix + '0'.repeat(15 - keyPrefix.length()));
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            try {
                AccountRatingCalculator.calculateAccountRating(fakeId);
                System.assert(false,
                    'Should throw exception for invalid account ID');
            } catch (AccountRatingCalculator.AccountRatingException e) {
                System.assert(e.getMessage().contains('not found'),
                    'Exception message should mention account not found');
            }
        }
        Test.stopTest();
    }
    
    /**
     * @description Test empty set handling
     */
    @isTest
    static void testEmptySetHandling() {
        Set<Id> emptySet = new Set<Id>();
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Map<Id, String> ratings = AccountRatingCalculator.calculateAccountRatings(emptySet);
            System.assertEquals(0, ratings.size(),
                'Should return empty map for empty set');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test null set handling
     */
    @isTest
    static void testNullSetHandling() {
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Map<Id, String> ratings = AccountRatingCalculator.calculateAccountRatings(null);
            System.assertEquals(0, ratings.size(),
                'Should return empty map for null set');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test revenue scoring tiers
     */
    @isTest
    static void testRevenueScoringTiers() {
        List<Account> testAccounts = new List<Account>();
        
        // Tier 1 - 3 points
        testAccounts.add(new Account(
            Name = 'Revenue Tier 1',
            AnnualRevenue = 10000000,
            NumberOfEmployees = 0
        ));
        
        // Tier 2 - 2 points
        testAccounts.add(new Account(
            Name = 'Revenue Tier 2',
            AnnualRevenue = 5000000,
            NumberOfEmployees = 0
        ));
        
        // Tier 3 - 1 point
        testAccounts.add(new Account(
            Name = 'Revenue Tier 3',
            AnnualRevenue = 1000000,
            NumberOfEmployees = 0
        ));
        
        insert testAccounts;
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            for (Account acc : testAccounts) {
                String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
                System.assertNotEquals(null, rating,
                    'Rating should be calculated for ' + acc.Name);
            }
        }
        Test.stopTest();
    }
    
    /**
     * @description Test employee scoring tiers
     */
    @isTest
    static void testEmployeeScoringTiers() {
        List<Account> testAccounts = new List<Account>();
        
        // Tier 1 - 3 points
        testAccounts.add(new Account(
            Name = 'Employee Tier 1',
            NumberOfEmployees = 1000,
            AnnualRevenue = 0
        ));
        
        // Tier 2 - 2 points
        testAccounts.add(new Account(
            Name = 'Employee Tier 2',
            NumberOfEmployees = 500,
            AnnualRevenue = 0
        ));
        
        // Tier 3 - 1 point
        testAccounts.add(new Account(
            Name = 'Employee Tier 3',
            NumberOfEmployees = 100,
            AnnualRevenue = 0
        ));
        
        insert testAccounts;
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            for (Account acc : testAccounts) {
                String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
                System.assertNotEquals(null, rating,
                    'Rating should be calculated for ' + acc.Name);
            }
        }
        Test.stopTest();
    }
    
    /**
     * @description Test opportunity scoring tiers
     */
    @isTest
    static void testOpportunityScoringTiers() {
        Account testAccount = new Account(
            Name = 'Opportunity Tier Test',
            AnnualRevenue = 0,
            NumberOfEmployees = 0
        );
        insert testAccount;
        
        // Create 10 opportunities for tier 1 (3 points)
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 10; i++) {
            opps.add(new Opportunity(
                Name = 'Test Opp ' + i,
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;
        
        Test.startTest();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String rating = AccountRatingCalculator.calculateAccountRating(testAccount.Id);
            System.assertNotEquals(null, rating,
                'Rating should be calculated');
        }
        Test.stopTest();
    }
}