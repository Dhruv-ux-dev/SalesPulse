import { LightningElement, api } from 'lwc';
import enrichAccounts from '@salesforce/apex/AccountEnrichmentService.enrichAccounts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AccountEnrichmentButton extends LightningElement {
    @api recordId;
    isBusy = false;
    statusMessage;
    statusClass = 'status-message';

    async handleEnrich() {
        if (!this.recordId || this.isBusy) return;
        this.isBusy = true;
        this.statusMessage = undefined;
        try {
            await enrichAccounts({ accountIds: [this.recordId] });
            this.statusMessage = 'Enrichment queued. Refresh the account record in a moment to see the result.';
            this.statusClass = 'status-message success';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Enrichment queued',
                message: 'The account will be updated when the background job finishes.',
                variant: 'success'
            }));
        } catch (error) {
            this.statusMessage = error?.body?.message || 'Unable to queue account enrichment.';
            this.statusClass = 'status-message error';
            this.dispatchEvent(new ShowToastEvent({ title: 'Unable to queue enrichment', message: this.statusMessage, variant: 'error' }));
        } finally {
            this.isBusy = false;
        }
    }
}
