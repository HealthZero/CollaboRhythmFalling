package collaboRhythm.core.model.healthRecord
{

	import collaboRhythm.core.model.healthRecord.service.AdherenceItemsHealthRecordService;
	import collaboRhythm.core.model.healthRecord.service.MedicationAdministrationsHealthRecordService;
	import collaboRhythm.core.model.healthRecord.service.VitalSignHealthRecordService;
	import collaboRhythm.shared.model.Account;
	import collaboRhythm.shared.model.Record;

	public class HealthRecordServiceFacade
	{
		private var _medicationAdministrationsHealthRecordService:MedicationAdministrationsHealthRecordService;
		private var _adherenceItemsHealthRecordService:AdherenceItemsHealthRecordService;
		private var _vitalSignHealthRecordService:VitalSignHealthRecordService;

		public function HealthRecordServiceFacade(consumerKey:String, consumerSecret:String, baseURL:String,
												  account:Account)
		{
			_medicationAdministrationsHealthRecordService = new MedicationAdministrationsHealthRecordService(consumerKey, consumerSecret, baseURL, account);
			_adherenceItemsHealthRecordService = new AdherenceItemsHealthRecordService(consumerKey, consumerSecret, baseURL, account);
			_vitalSignHealthRecordService = new VitalSignHealthRecordService(consumerKey, consumerSecret, baseURL, account);
		}

		/**
		 * Loads all supported documents for the Record and initializes any XML marshallers on the associated models.
		 * @param record
		 */
		public function loadDocuments(record:Record):void
		{
			record.adherenceItemsModel.adherenceItemXmlMarshaller = _adherenceItemsHealthRecordService;

			_medicationAdministrationsHealthRecordService.getMedicationAdministrations(record);
			_adherenceItemsHealthRecordService.getAdherenceItems(record);
			_vitalSignHealthRecordService.loadVitalSigns(record);
		}
	}
}
