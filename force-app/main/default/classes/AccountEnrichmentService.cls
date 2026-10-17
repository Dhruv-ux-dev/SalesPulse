public with sharing class AccountEnrichmentService implements Queueable, Database.AllowsCallouts {
    private static final Integer MAX_RECORDS_PER_EXECUTION = 50;
    private List<Id> accountIds;

    public AccountEnrichmentService(List<Id> accountIds) {
        this.accountIds = accountIds == null ? new List<Id>() : new List<Id>(new Set<Id>(accountIds));
    }

    @AuraEnabled
    public static void enrichAccounts(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return;
        List<Id> cleanIds = new List<Id>();
        for (Id accountId : accountIds) {
            if (accountId != null && !cleanIds.contains(accountId)) cleanIds.add(accountId);
        }
        if (!cleanIds.isEmpty()) System.enqueueJob(new AccountEnrichmentService(cleanIds));
    }

    public void execute(QueueableContext context) {
        if (accountIds.isEmpty()) return;
        Integer batchSize = accountIds.size() < MAX_RECORDS_PER_EXECUTION ? accountIds.size() : MAX_RECORDS_PER_EXECUTION;
        List<Id> currentIds = new List<Id>();
        List<Id> remainingIds = new List<Id>();
        for (Integer index = 0; index < accountIds.size(); index++) {
            if (index < batchSize) currentIds.add(accountIds[index]);
            else remainingIds.add(accountIds[index]);
        }

        List<Account> accounts = [
            SELECT Id, Website, Phone, Description, Enrichment_Status__c
            FROM Account WHERE Id IN :currentIds
            WITH USER_MODE
        ];
        List<Account> updates = new List<Account>();
        for (Account accountRecord : accounts) {
            Account changed = new Account(Id=accountRecord.Id, Enrichment_Status__c='Failed');
            String domain = extractDomain(accountRecord.Website);
            if (String.isBlank(domain)) {
                updates.add(changed);
                continue;
            }
            try {
                HttpRequest request = new HttpRequest();
                request.setMethod('GET');
                request.setEndpoint('callout:CompanyData/v1/company?domain=' + EncodingUtil.urlEncode(domain, 'UTF-8'));
                request.setTimeout(15000);
                HttpResponse response = new Http().send(request);
                if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                    Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                    if (payload.containsKey('description') && payload.get('description') != null) {
                        changed.Description = String.valueOf(payload.get('description'));
                    }
                    if (payload.containsKey('phone') && payload.get('phone') != null) {
                        changed.Phone = String.valueOf(payload.get('phone'));
                    }
                    if (payload.containsKey('website') && payload.get('website') != null) {
                        changed.Website = String.valueOf(payload.get('website'));
                    }
                    changed.Enrichment_Status__c = 'Enriched';
                }
            } catch (Exception ex) {
                // Avoid logging customer data or exception payloads; record a safe status instead.
                changed.Enrichment_Status__c = 'Failed';
            }
            updates.add(changed);
        }
        if (!updates.isEmpty()) update as user updates;
        if (!remainingIds.isEmpty()) System.enqueueJob(new AccountEnrichmentService(remainingIds));
    }

    @TestVisible
    private static String extractDomain(String website) {
        if (String.isBlank(website)) return null;
        String candidate = website.trim().toLowerCase();
        candidate = candidate.replaceAll('^https?://', '');
        candidate = candidate.replaceAll('^www\\.', '');
        Integer slashIndex = candidate.indexOf('/');
        if (slashIndex >= 0) candidate = candidate.substring(0, slashIndex);
        Integer queryIndex = candidate.indexOf('?');
        if (queryIndex >= 0) candidate = candidate.substring(0, queryIndex);
        Integer colonIndex = candidate.indexOf(':');
        if (colonIndex >= 0) candidate = candidate.substring(0, colonIndex);
        return String.isBlank(candidate) ? null : candidate;
    }
}
