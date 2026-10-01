/**
 * @description Assigns Hot/Warm/Cold ratings to Accounts using a point-based
 *              scoring system derived from AnnualRevenue, NumberOfEmployees,
 *              and related Opportunities.
 *
 *              Scoring thresholds:
 *                7+ points => Hot
 *                4+ points => Warm
 *                <4 points => Cold
 *
 *              Revenue points:
 *                >= 1,000,000  => 4 pts
 *                >= 500,000    => 2 pts
 *                >= 100,000    => 1 pt
 *
 *              Employee points:
 *                >= 1,000 => 3 pts
 *                >= 200   => 2 pts
 *                >= 50    => 1 pt
 *
 *              Opportunity points (Closed Won):
 *                >= 3 => 3 pts
 *                >= 1 => 1 pt
 */
public with sharing class AccountRatingCalculator {

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    private static final Integer POINTS_HOT  = 7;
    private static final Integer POINTS_WARM = 4;

    private static final Decimal REVENUE_HIGH   = 1000000;
    private static final Decimal REVENUE_MED    = 500000;
    private static final Decimal REVENUE_LOW    = 100000;

    private static final Integer EMP_HIGH = 1000;
    private static final Integer EMP_MED  = 200;
    private static final Integer EMP_LOW  = 50;

    private static final String RATING_HOT  = 'Hot';
    private static final String RATING_WARM = 'Warm';
    private static final String RATING_COLD = 'Cold';

    // -------------------------------------------------------------------------
    // Public entry point – called by the auto-launched Flow
    // -------------------------------------------------------------------------

    /**
     * @description Calculates and assigns ratings for a list of Account Ids.
     *              Designed to be called from a Flow via @InvocableMethod.
     * @param accountIds List of Account Ids to process.
     */
    @InvocableMethod(label='Calculate Account Rating' description='Assigns Hot/Warm/Cold rating to Accounts based on revenue, employees, and opportunities.')
    public static void calculateRatings(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        // Bulkified SOQL – one query for accounts, one for opportunities
        List<Account> accounts = [
            SELECT Id, AnnualRevenue, NumberOfEmployees, Rating
            FROM Account
            WHERE Id IN :accountIds
            WITH USER_MODE
        ];

        Map<Id, Integer> oppCountByAccountId = getClosedWonOppCounts(accountIds);

        List<Account> toUpdate = new List<Account>();
        for (Account acc : accounts) {
            String newRating = computeRating(acc, oppCountByAccountId.get(acc.Id));
            if (acc.Rating != newRating) {
                toUpdate.add(new Account(Id = acc.Id, Rating = newRating));
            }
        }

        if (!toUpdate.isEmpty()) {
            update as user toUpdate;
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * @description Returns a map of Account Id to Closed Won opportunity count.
     * @param accountIds Account Ids to query.
     * @return Map of Account Id to opportunity count.
     */
    private static Map<Id, Integer> getClosedWonOppCounts(List<Id> accountIds) {
        Map<Id, Integer> countMap = new Map<Id, Integer>();
        for (Id accId : accountIds) {
            countMap.put(accId, 0);
        }
        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) oppCount
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND StageName = 'Closed Won'
            WITH USER_MODE
            GROUP BY AccountId
        ]) {
            countMap.put((Id) ar.get('AccountId'), (Integer) ar.get('oppCount'));
        }
        return countMap;
    }

    /**
     * @description Computes the rating string for a single Account.
     * @param acc The Account record.
     * @param oppCount Number of Closed Won opportunities.
     * @return Rating string: Hot, Warm, or Cold.
     */
    @TestVisible
    private static String computeRating(Account acc, Integer oppCount) {
        Integer points = 0;
        points += revenuePoints(acc.AnnualRevenue);
        points += employeePoints(acc.NumberOfEmployees);
        points += opportunityPoints(oppCount);

        if (points >= POINTS_HOT) {
            return RATING_HOT;
        } else if (points >= POINTS_WARM) {
            return RATING_WARM;
        } else {
            return RATING_COLD;
        }
    }

    /**
     * @description Returns revenue-based points.
     * @param revenue AnnualRevenue value.
     * @return Integer points.
     */
    private static Integer revenuePoints(Decimal revenue) {
        if (revenue == null) {
            return 0;
        }
        if (revenue >= REVENUE_HIGH) {
            return 4;
        } else if (revenue >= REVENUE_MED) {
            return 2;
        } else if (revenue >= REVENUE_LOW) {
            return 1;
        }
        return 0;
    }

    /**
     * @description Returns employee-count-based points.
     * @param empCount NumberOfEmployees value.
     * @return Integer points.
     */
    private static Integer employeePoints(Integer empCount) {
        if (empCount == null) {
            return 0;
        }
        if (empCount >= EMP_HIGH) {
            return 3;
        } else if (empCount >= EMP_MED) {
            return 2;
        } else if (empCount >= EMP_LOW) {
            return 1;
        }
        return 0;
    }

    /**
     * @description Returns opportunity-count-based points.
     * @param oppCount Number of Closed Won opportunities.
     * @return Integer points.
     */
    private static Integer opportunityPoints(Integer oppCount) {
        if (oppCount == null || oppCount == 0) {
            return 0;
        }
        if (oppCount >= 3) {
            return 3;
        }
        return 1;
    }
}