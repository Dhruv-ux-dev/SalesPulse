import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/SalesPulseDashboardController.getDashboardData';

const CURRENCY = new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0
});

const COLUMNS = [
    { label: 'Opportunity', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, initialWidth: 240 },
    { label: 'Account', fieldName: 'accountName', type: 'text' },
    { label: 'Stage', fieldName: 'StageName', type: 'text' },
    { label: 'Amount', fieldName: 'Amount', type: 'currency', typeAttributes: { currencyCode: 'USD', maximumFractionDigits: 0 } },
    { label: 'Close Date', fieldName: 'CloseDate', type: 'date-local' },
    { label: 'Health', fieldName: 'Health_Status__c', type: 'text' },
    { label: 'Next Action', fieldName: 'Next_Action_Date__c', type: 'date-local' },
    { label: 'Owner', fieldName: 'ownerName', type: 'text' }
];

export default class SalesPulseDashboard extends LightningElement {
    data;
    errorMessage;
    isLoading = true;
    wiredResult;
    columns = COLUMNS;

    @wire(getDashboardData)
    wiredDashboard(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.data = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.data = undefined;
            this.errorMessage = result.error?.body?.message || 'Unable to load the SalesPulse dashboard.';
        }
    }

    get formattedOpenPipeline() {
        return CURRENCY.format(this.data?.openPipelineAmount || 0);
    }

    get formattedClosedWon() {
        return CURRENCY.format(this.data?.closedWonAmount || 0);
    }

    get formattedWinRate() {
        return `${Number(this.data?.winRate || 0).toFixed(1)}%`;
    }

    get opportunityRows() {
        return (this.data?.recentOpportunities || []).map((row) => ({
            ...row,
            recordUrl: `/lightning/r/Opportunity/${row.Id}/view`,
            accountName: row.Account?.Name || '—',
            ownerName: row.Owner?.Name || '—'
        }));
    }

    async handleRefresh() {
        if (!this.wiredResult) return;
        this.isLoading = true;
        try {
            await refreshApex(this.wiredResult);
        } finally {
            this.isLoading = false;
        }
    }
}
