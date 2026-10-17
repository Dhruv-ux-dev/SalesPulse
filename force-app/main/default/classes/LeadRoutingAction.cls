public with sharing class LeadRoutingAction {
    public class Request {
        @InvocableVariable(label='Lead Id' required=true)
        public Id leadId;
    }

    @InvocableMethod(label='Score and Assign Lead' description='Scores incoming leads and routes them to the Sales Inbound queue when configured.')
    public static void scoreAndAssign(List<Request> requests) {
        if (requests == null || requests.isEmpty()) return;

        Set<Id> leadIds = new Set<Id>();
        for (Request requestItem : requests) {
            if (requestItem != null && requestItem.leadId != null) leadIds.add(requestItem.leadId);
        }
        if (leadIds.isEmpty()) return;

        Map<String, Id> queueIdsByDeveloperName = new Map<String, Id>();
        for (Group queueRecord : [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName = 'Sales_Inbound'
        ]) {
            queueIdsByDeveloperName.put(queueRecord.DeveloperName, queueRecord.Id);
        }

        List<Lead> leadsToUpdate = new List<Lead>();
        for (Lead leadRecord : [
            SELECT Id, OwnerId, Industry, AnnualRevenue, NumberOfEmployees,
                   Email, Website, LeadSource, Lead_Score__c, Lead_Rating__c
            FROM Lead
            WHERE Id IN :leadIds
        ]) {
            Integer score = calculateScore(leadRecord);
            leadRecord.Lead_Score__c = score;
            leadRecord.Lead_Rating__c = score >= 70 ? 'Hot' : (score >= 40 ? 'Warm' : 'Cold');
            if (queueIdsByDeveloperName.containsKey('Sales_Inbound')) {
                leadRecord.OwnerId = queueIdsByDeveloperName.get('Sales_Inbound');
            }
            leadsToUpdate.add(leadRecord);
        }
        if (!leadsToUpdate.isEmpty()) update leadsToUpdate;
    }

    @TestVisible
    private static Integer calculateScore(Lead leadRecord) {
        Integer score = 0;
        if (leadRecord == null) return score;

        Set<String> priorityIndustries = new Set<String>{'Technology', 'Finance', 'Healthcare', 'Manufacturing'};
        if (String.isNotBlank(leadRecord.Industry) && priorityIndustries.contains(leadRecord.Industry)) score += 20;

        if (leadRecord.AnnualRevenue != null) {
            if (leadRecord.AnnualRevenue >= 1000000) score += 20;
            else if (leadRecord.AnnualRevenue >= 250000) score += 10;
        }
        if (leadRecord.NumberOfEmployees != null) {
            if (leadRecord.NumberOfEmployees >= 200) score += 15;
            else if (leadRecord.NumberOfEmployees >= 50) score += 10;
        }
        if (String.isNotBlank(leadRecord.Email)) score += 10;
        if (String.isNotBlank(leadRecord.Website)) score += 10;
        if (leadRecord.LeadSource == 'Partner' || leadRecord.LeadSource == 'Partner Referral' || leadRecord.LeadSource == 'Referral') score += 15;
        else if (leadRecord.LeadSource == 'Web') score += 10;

        return score > 100 ? 100 : score;
    }
}
