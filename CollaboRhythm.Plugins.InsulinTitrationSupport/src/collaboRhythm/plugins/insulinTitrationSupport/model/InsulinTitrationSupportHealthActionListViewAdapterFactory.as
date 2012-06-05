package collaboRhythm.plugins.insulinTitrationSupport.model
{
	import collaboRhythm.plugins.schedule.shared.model.IHealthActionListViewAdapter;
	import collaboRhythm.plugins.schedule.shared.model.IHealthActionListViewAdapterFactory;
	import collaboRhythm.plugins.schedule.shared.model.IHealthActionModelDetailsProvider;
	import collaboRhythm.shared.model.healthRecord.document.HealthActionPlan;
	import collaboRhythm.shared.model.healthRecord.document.HealthActionSchedule;
	import collaboRhythm.shared.model.healthRecord.document.ScheduleItemOccurrence;

	import mx.collections.ArrayCollection;

	public class InsulinTitrationSupportHealthActionListViewAdapterFactory implements IHealthActionListViewAdapterFactory
	{
		public function InsulinTitrationSupportHealthActionListViewAdapterFactory()
		{
		}

		public function createUnscheduledHealthActionViewAdapters(healthActionModelDetailsProvider:IHealthActionModelDetailsProvider,
																  adapters:ArrayCollection):void
		{
			adapters.addItem(new InsulinTitrationSupportHealthActionListViewAdapter(null, healthActionModelDetailsProvider));
		}

		public function createScheduledHealthActionViewAdapter(scheduleItemOccurrence:ScheduleItemOccurrence,
															   healthActionModelDetailsProvider:IHealthActionModelDetailsProvider,
															   currentHealthActionListViewAdapter:IHealthActionListViewAdapter):IHealthActionListViewAdapter
		{
			var healthActionSchedule:HealthActionSchedule = scheduleItemOccurrence.scheduleItem as HealthActionSchedule;
			if (healthActionSchedule && healthActionSchedule.scheduledHealthAction is HealthActionPlan)
				return new InsulinTitrationSupportHealthActionListViewAdapter(scheduleItemOccurrence, healthActionModelDetailsProvider);
			else
				return currentHealthActionListViewAdapter;
		}
	}
}
