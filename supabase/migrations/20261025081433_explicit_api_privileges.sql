-- Defense in depth: authenticated application APIs; trusted maintenance/provisioning only.
SET local check_function_bodies = off;

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON FUNCTIONS FROM "anon";

REVOKE ALL ON FUNCTION "public"."accounting_export"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."appointments_for_day"(date) FROM "anon";

REVOKE ALL ON FUNCTION "public"."authorize"(text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."billing_patient_search"(text, integer) FROM "anon";

REVOKE ALL ON FUNCTION "public"."clinical_record"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."command"(text, jsonb, uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."current_photography_consent"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."financial_report"(text, date, date, uuid, integer, timestamp WITH time zone) FROM "anon";

REVOKE ALL ON FUNCTION "public"."media_access"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."media_finalize"(uuid, boolean) FROM "anon";

REVOKE ALL ON FUNCTION "public"."media_finalize"(uuid, boolean) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."media_prepare"(uuid, uuid, uuid, text, text, text, text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."patient_profile"(uuid) FROM "anon";

REVOKE ALL ON FUNCTION "public"."patient_search"(text, uuid, integer) FROM "anon";

REVOKE ALL ON FUNCTION "public"."provision_member"(uuid, uuid, text, text) FROM "anon";

REVOKE ALL ON FUNCTION "public"."provision_member"(uuid, uuid, text, text) FROM "authenticated";

REVOKE ALL ON FUNCTION "public"."retention_state"() FROM "anon";

REVOKE ALL ON FUNCTION "public"."workspace"() FROM "anon";

