SAMARA CARE V17 – ABNORMAL VITAL ALERTS & NOTIFICATIONS

1. Run supabase/06_V17_ALERTS_NOTIFICATIONS.sql once.
2. Upload app files to Samara_AL_005 repository root.
3. Open https://rajaiahboomi-crypto.github.io/Samara_AL_005/?v=17

Abnormal vital values are automatically classified as Warning or Critical and entered in Clinical Alerts. WhatsApp/SMS messages are placed in Notification Queue.

Automatic external delivery requires provider setup:
- WhatsApp Business Cloud API account, phone number ID, access token, and approved templates/consent.
- SMS provider account, Indian DLT Principal Entity/header/content templates/consent.
- Deploy supabase/functions/send-notifications and add provider secrets.

Until provider activation, Admin/Manager can open queued WhatsApp messages manually from the Notifications module.

Clinical thresholds in the app are initial operational defaults and must be reviewed and approved by the facility doctor.
