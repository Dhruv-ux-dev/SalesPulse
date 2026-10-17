public with sharing class SalesPulseDashboardController {
    public class DashboardData {
        @AuraEnabled public Decimal openPipelineAmount { get; set; }
        @AuraEnabled public Decimal closedWonAmount { get; set; }
        @AuraEnabled public Integer openOpportunityCount { get; set; }
        @AuraEnabled public Decimal winRate { get; set; }
        @AuraEnabled public List<Opportunity> recentOpportunities { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        DashboardData result = new DashboardData();
        AggregateResult[] openAgg = [
            SELECT SUM(Amount) totalAmount, COUNT(Id) recordCount
            FROM Opportunity WHERE IsClosed = false
            WITH USER_MODE
        ];
        AggregateResult[] wonAgg = [
            SELECT SUM(Amount) totalAmount, COUNT(Id) recordCount
            FROM Opportunity WHERE IsWon = true
            WITH USER_MODE
        ];
        AggregateResult[] closedAgg = [
            SELECT COUNT(Id) recordCount
            FROM Opportunity WHERE IsClosed = true
            WITH USER_MODE
        ];

        result.openPipelineAmount = (Decimal)openAgg[0].get('totalAmount');
        result.closedWonAmount = (Decimal)wonAgg[0].get('totalAmount');
        result.openOpportunityCount = (Integer)openAgg[0].get('recordCount');
        Integer wonCount = (Integer)wonAgg[0].get('recordCount');
        Integer closedCount = (Integer)closedAgg[0].get('recordCount');
        result.winRate = closedCount == 0 ? 0 : (Decimal.valueOf(String.valueOf(wonCount)) * 100 / closedCount).setScale(1);
        result.recentOpportunities = [
            SELECT Id, Name, Account.Name, StageName, Amount, CloseDate, Owner.Name,
                   Health_Status__c, Next_Action_Date__c
            FROM Opportunity
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 25
        ];
        return result;
    }
}
