@IsTest
private class SalesPulseDashboardControllerTest {
    @IsTest
    static void dashboardReturnsPipelineMetrics() {
        Account accountRecord = new Account(Name='Dashboard Test Account');
        insert accountRecord;

        insert new List<Opportunity>{
            new Opportunity(Name='Open Deal', AccountId=accountRecord.Id, StageName='Prospecting', CloseDate=Date.today().addDays(21), Amount=100),
            new Opportunity(Name='Won Deal', AccountId=accountRecord.Id, StageName='Closed Won', CloseDate=Date.today().addDays(-3), Amount=500),
            new Opportunity(Name='Lost Deal', AccountId=accountRecord.Id, StageName='Closed Lost', CloseDate=Date.today().addDays(-1), Amount=200)
        };

        Test.startTest();
        SalesPulseDashboardController.DashboardData result = SalesPulseDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(100, result.openPipelineAmount);
        System.assertEquals(500, result.closedWonAmount);
        System.assertEquals(1, result.openOpportunityCount);
        System.assertEquals(50.0, result.winRate);
        System.assertEquals(3, result.recentOpportunities.size());
    }
}
