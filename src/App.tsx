import { Help } from "./features/help";
import { PhoneReminders } from "./features/phone-reminders";
import { hasRole } from "./domain/staff";
import { AppointmentsPage } from "./features/appointments";
import {
  lazy,
  Suspense,
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { Session } from "@supabase/supabase-js";
import {
  Activity,
  ArrowRight,
  CalendarDays,
  Check,
  ChevronRight,
  CircleDollarSign,
  ClipboardList,
  FileHeart,
  Home,
  Image,
  Languages,
  LoaderCircle,
  PanelLeft,
  LogOut,
  Package,
  Plus,
  RefreshCw,
  Settings,
  ShieldCheck,
  Stethoscope,
  Users,
  Wallet,
} from "lucide-react";
import { configured, client } from "./lib/supabase";
import { snapshot, clinicalRecord } from "./lib/api";
import { translate } from "./lib/i18n";
import { ageAt } from "./domain/patient";
import { money } from "./domain/money";
import type { Currency, Locale, Patient, Row, Snapshot } from "./domain/types";
import {
  Badge,
  CommandDialog,
  DataTable,
  Empty,
  ErrorMessage,
  Loading,
  options,
  type Action,
  type T,
} from "./components/ui";
import {
  appointmentAction,
  choice,
  consentAction,
  currency,
  encounter,
  encounterAction,
  expenseAction,
  invoiceAction,
  number,
  patient,
  patientAction,
  paymentAction,
  procedureAction,
  stockAction,
  text,
} from "./features/actions";
import { formatDate, day, str } from "./lib/format";
const Billing = lazy(() =>
  import("./features/billing").then((module) => ({ default: module.Billing })),
);
const Finance = lazy(() =>
  import("./features/finance").then((module) => ({ default: module.Finance })),
);
const Reports = lazy(() =>
  import("./features/reports").then((module) => ({ default: module.Reports })),
);
const Team = lazy(() =>
  import("./features/team").then((module) => ({ default: module.Team })),
);
import { MediaWorkspace as MediaPanel } from "./features/media";
import { RecordPager, useRecordPage } from "./components/RecordPager";
import { Accounting } from "./features/accounting";
import { ClinicalSharing, Retention } from "./features/access";
import { InventoryTools } from "./features/inventory";
import {
  Treatments,
  PatientTools,
  ScheduleTools,
  StockActions,
} from "./features/workflows";
import { PatientDirectory } from "./features/patients";
import { AccountPanel } from "./features/account";
import { usernameIdentity } from "../supabase/functions/_shared/username";
import { MfaPanel } from "./features/security";

const navigation = [
  { id: "overview", label: "Overview", icon: Home, permission: "" },
  { id: "patients", label: "Patients", icon: Users, permission: "patients" },
  {
    id: "treatments",
    label: "Treatments",
    icon: ClipboardList,
    permission: "schedule",
  },
  {
    id: "appointments",
    label: "Appointments",
    icon: CalendarDays,
    permission: "schedule",
  },
  {
    id: "clinical",
    label: "Clinical records",
    icon: FileHeart,
    permission: "clinical",
  },
  { id: "media", label: "Clinical media", icon: Image, permission: "media" },
  {
    id: "results",
    label: "Results & follow-up",
    icon: ClipboardList,
    permission: "results",
  },
  {
    id: "billing",
    label: "Billing",
    icon: CircleDollarSign,
    permission: "billing",
  },
  { id: "finance", label: "Finance", icon: Wallet, permission: "finance" },
  {
    id: "accounting",
    label: "Accounting",
    icon: ClipboardList,
    permission: "finance",
  },
  {
    id: "inventory",
    label: "Inventory",
    icon: Package,
    permission: "inventory",
  },
  { id: "reports", label: "Reports", icon: Activity, permission: "finance" },
  {
    id: "team",
    label: "Team & access",
    icon: ShieldCheck,
    permission: "staff",
  },
  { id: "settings", label: "Settings", icon: Settings, permission: "settings" },
  {
    id: "retention",
    label: "Retention & holds",
    icon: ShieldCheck,
    permission: "staff",
  },
  { id: "help", label: "Help & user guide", icon: FileHeart, permission: "" },
];
export function App() {
  const [navigationOpen, setNavigationOpen] = useState(
    () => window.innerWidth > 760,
  );
  const [patientView, setPatientView] = useState({ id: "", section: "" });
  const [locale, setLocale] = useState<Locale>(() =>
    localStorage.getItem("clinicos.locale") === "ckb" ? "ckb" : "en",
  );
  const [session, setSession] = useState<Session | null>(null),
    [authReady, setAuthReady] = useState(false),
    [data, setData] = useState<Snapshot | null>(null),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(false);
  const [route, setRoute] = useState(location.hash.slice(1) || "overview"),
    [action, setAction] = useState<Action | null>(null),
    [notice, setNotice] = useState(""),
    [search, setSearch] = useState("");
  const [record, setRecord] = useState<{
      encounters: Row[];
      procedures: Row[];
      facts?: Row[];
    } | null>(null),
    [recordError, setRecordError] = useState("");
  const generation = useRef(0);
  const recordGeneration = useRef(0),
    refreshGeneration = useRef(0);
  const authIdentity = useRef<string | undefined>(undefined);
  const t: T = useCallback((s) => translate(locale, s), [locale]);
  useEffect(() => {
    const compact = window.matchMedia("(max-width: 760px)");
    const collapse = () => {
      if (compact.matches) setNavigationOpen(false);
    };
    compact.addEventListener("change", collapse);
    return () => compact.removeEventListener("change", collapse);
  }, []);
  const navigate = (to: string) => {
    location.hash = to;
    if (window.innerWidth <= 760) setNavigationOpen(false);
  };
  useEffect(() => {
    document.documentElement.lang = locale;
    document.documentElement.dir = locale === "ckb" ? "rtl" : "ltr";
    localStorage.setItem("clinicos.locale", locale);
  }, [locale]);
  useEffect(() => {
    const change = () => {
      setRoute(location.hash.slice(1) || "overview");
      setSearch("");
    };
    window.addEventListener("hashchange", change);
    return () => window.removeEventListener("hashchange", change);
  }, []);
  useEffect(() => {
    if (!configured) {
      setAuthReady(true);
      return;
    }
    const {
      data: { subscription },
    } = client().auth.onAuthStateChange((_e, s) => {
      generation.current++;
      if (authIdentity.current !== s?.user.id) {
        authIdentity.current = s?.user.id;
        setData(null);
        setAction(null);
        setRecord(null);
        setRecordError("");
        setSearch("");
        setPatientView({ id: "", section: "" });
        location.hash = "overview";
      }
      if (s && _e === "PASSWORD_RECOVERY") location.hash = "account";
      setSession(s);
      setError("");
      setAuthReady(true);
    });
    void client()
      .auth.getSession()
      .then(({ data: { session: s } }) => {
        setSession(s);
        setAuthReady(true);
      });
    return () => subscription.unsubscribe();
  }, []);
  const refresh = useCallback(async () => {
    const current = generation.current;
    const sequence = ++refreshGeneration.current;
    setLoading(true);
    try {
      const next = await snapshot();
      const profileId = location.hash.match(
        /^#patients\/([a-f0-9-]{36})$/,
      )?.[1];
      if (profileId && !next.patients.some((p) => p.id === profileId)) {
        const { data: profile, error: profileError } = await client().rpc(
          "patient_profile",
          { patient_id: profileId },
        );
        if (profileError) throw profileError;
        if (profile) next.patients.push(profile);
      }
      if (
        current === generation.current &&
        sequence === refreshGeneration.current
      ) {
        setData(next);
        setError("");
      }
    } catch (e) {
      if (
        current === generation.current &&
        sequence === refreshGeneration.current
      )
        setError(e instanceof Error ? e.message : "Connection failed");
    } finally {
      if (sequence === refreshGeneration.current) setLoading(false);
    }
  }, []);
  useEffect(() => {
    if (session) void refresh();
  }, [session?.access_token, refresh]);
  useEffect(() => {
    if (!session) return;
    let timer: ReturnType<typeof setTimeout>;
    const reset = () => {
      clearTimeout(timer);
      timer = setTimeout(
        () => {
          void client().auth.signOut();
        },
        15 * 60 * 1000,
      );
    };
    reset();
    window.addEventListener("pointerdown", reset);
    window.addEventListener("keydown", reset);
    return () => {
      clearTimeout(timer);
      window.removeEventListener("pointerdown", reset);
      window.removeEventListener("keydown", reset);
    };
  }, [session?.user.id]);
  useEffect(() => {
    const online = () => {
      if (session) void refresh();
    };
    const offline = () =>
      setError(t("Connection lost. Changes require confirmation."));
    window.addEventListener("online", online);
    window.addEventListener("offline", offline);
    return () => {
      window.removeEventListener("online", online);
      window.removeEventListener("offline", offline);
    };
  }, [session, t, refresh]);
  const selected = route.startsWith("patients/")
    ? data?.patients.find((p) => p.id === route.split("/")[1])
    : undefined;
  const patientSection =
    patientView.id === selected?.id
      ? patientView.section
      : data?.permissions.includes("clinical")
        ? "records"
        : "contacts";
  useEffect(() => {
    const id = route.match(/^patients\/([a-f0-9-]{36})$/)?.[1];
    if (!id || !data || selected) return;
    let cancelled = false;
    const authGeneration = generation.current;
    void client()
      .rpc("patient_profile", { patient_id: id })
      .then(({ data: profile, error: profileError }) => {
        if (cancelled || authGeneration !== generation.current) return;
        if (profileError || !profile) {
          setError(profileError?.message ?? "Patient unavailable");
          return;
        }
        setData((d) =>
          d
            ? {
                ...d,
                patients: [
                  ...d.patients.filter((p) => p.id !== profile.id),
                  profile,
                ],
              }
            : d,
        );
      });
    return () => {
      cancelled = true;
    };
  }, [route, data?.organization.id, selected?.id]);
  useEffect(() => {
    if (selected?.merged_into) navigate(`patients/${selected.merged_into}`);
  }, [selected?.merged_into]);
  const loadRecord = useCallback(async (id: string) => {
    const sequence = ++recordGeneration.current,
      authGeneration = generation.current;
    setRecord(null);
    setRecordError("");
    try {
      const response = await clinicalRecord(id);
      if (
        sequence === recordGeneration.current &&
        authGeneration === generation.current &&
        location.hash === `#patients/${id}`
      )
        setRecord(response);
    } catch (e) {
      if (
        sequence !== recordGeneration.current ||
        authGeneration !== generation.current
      )
        return;
      setRecordError(
        e instanceof Error ? e.message : "Unable to load clinical record",
      );
    }
  }, []);
  useEffect(() => {
    if (selected && data?.permissions.includes("clinical"))
      void loadRecord(selected.id);
    else {
      recordGeneration.current++;
      setRecord(null);
    }
  }, [
    selected?.id,
    data?.permissions.join(","),
    session?.access_token,
    loadRecord,
  ]);
  const saved = async () => {
    await refresh();
    if (selected && data?.permissions.includes("clinical"))
      await loadRecord(selected.id);
    setNotice(t("Saved successfully"));
    setTimeout(() => setNotice(""), 3500);
  };
  const toggleLocale = () => setLocale(locale === "en" ? "ckb" : "en");
  const clinicalPage = useRecordPage(
    "encounters",
    route === "clinical" && data?.permissions.includes("clinical")
      ? data
      : null,
  );
  const resultsPage = useRecordPage(
    "results",
    route === "results" && data?.permissions.includes("results") ? data : null,
  );
  const tasksPage = useRecordPage(
    "tasks",
    route === "results" && data?.permissions.includes("results") ? data : null,
  );
  const stockPage = useRecordPage(
    "stock_lots",
    route === "inventory" &&
      (data?.permissions.includes("inventory") ||
        data?.permissions.includes("inventory.read"))
      ? data
      : null,
  );
  if (!authReady)
    return (
      <div className="splash">
        <LoaderCircle className="spin" />
        {t("Workspace")}
      </div>
    );
  if (!session)
    return <Login t={t} toggleLocale={toggleLocale} notice={notice} />;
  if (!data)
    return (
      <div className="splash">
        <div className="brand-mark">
          <Stethoscope />
        </div>
        <h1>ClinicOS</h1>
        {loading ? (
          <LoaderCircle className="spin" />
        ) : (
          <>
            <ErrorMessage error={error || "Loading workspace…"} />
            <button className="button primary" onClick={() => void refresh()}>
              {t("Retry")}
            </button>
            <button
              className="button secondary"
              onClick={() => void client().auth.signOut()}
            >
              {t("Sign out")}
            </button>
          </>
        )}
      </div>
    );
  const can = (p: string) => data.permissions.includes(p);
  const page = data.account?.password_change_required
    ? "account"
    : route.split("/")[0];
  const patientLabels = new Map<string, string>();
  for (const collection of [
    data.appointments,
    data.payments,
    data.tasks,
    data.results,
  ])
    for (const row of collection) {
      if (row.patient_id && row.patient_name)
        patientLabels.set(String(row.patient_id), String(row.patient_name));
    }
  for (const invoice of data.invoices) {
    const p = invoice.patient_snapshot as Record<string, unknown>;
    if (p?.full_name)
      patientLabels.set(String(invoice.patient_id), String(p.full_name));
  }
  for (const patient of data.patients)
    patientLabels.set(patient.id, patient.full_name);
  const patientName = (id: unknown) => patientLabels.get(String(id)) ?? "—";
  const doctorName = (id: unknown) =>
    data.members.find((m) => m.user_id === id)?.display_name ?? "—";
  const heading = selected
    ? selected.full_name
    : page === "account"
      ? "Account & security"
      : (navigation.find((n) => n.id === page)?.label ?? "Overview");
  const today = data.appointments.filter(
    (a) => day(a.starts_at) === day(new Date().toISOString()),
  );
  const activePatients = data.patients.filter((p) => !p.merged_into);

  const openInvoice = (inv: Row) => Number(inv.balance ?? 0);
  const primaryAction = selected
    ? can("clinical")
      ? () => setAction(encounterAction(data, selected.id))
      : () => setAction(appointmentAction(data, selected.id))
    : (
        {
          patients: () => setAction(patientAction()),
          appointments: () => setAction(appointmentAction(data)),
          clinical: () => setAction(encounterAction(data)),
          billing: () => setAction(invoiceAction(data)),
          finance: () => setAction(expenseAction()),
          inventory: () => setAction(stockAction()),
          results: () =>
            setAction({
              title: "New result order",
              kind: "result.create",
              fields: [
                patient(data),
                text("order_name", "Order name"),
                text("body_site", "Body site"),
                text("specimen_reference", "Specimen reference"),
                {
                  name: "due_at",
                  label: "Due date",
                  type: "datetime-local",
                  required: true,
                },
              ],
            }),
          settings: () =>
            setAction({
              title: "Add service",
              kind: "service.save",
              fields: [
                text("name", "Service"),
                text("name_ckb", "Name in Sorani"),
                choice(
                  "category",
                  "Category",
                  ["medical", "cosmetic"],
                  "medical",
                ),
                currency(),
                number("price", "Price"),
                {
                  ...number("duration", "Duration (minutes)", 30),
                  step: "1",
                  min: "5",
                  max: "480",
                },
              ],
            }),
        } as Record<string, () => void>
      )[page];
  const primaryLabel = selected
    ? can("clinical")
      ? "New encounter"
      : "New appointment"
    : (
        {
          patients: "New patient",
          appointments: "New appointment",
          clinical: "New encounter",
          billing: "New invoice",
          finance: "Record expense",
          inventory: "Receive stock",
          results: "New result order",
          settings: "Add service",
        } as Record<string, string>
      )[page];
  function appointmentRows(rows: Row[]) {
    return rows.map((a) => (
      <tr key={a.id}>
        <td className="mono">{formatDate(a.starts_at, true, locale)}</td>
        <td>
          <button
            className="text-button strong"
            onClick={() => navigate(`patients/${a.patient_id}`)}
          >
            {String(a.patient_name ?? patientName(a.patient_id))}
          </button>
        </td>
        <td>{str(a, "service_name")}</td>
        <td>{doctorName(a.doctor_id)}</td>
        <td>
          <Badge status={a.status} t={t} />
        </td>
        <td>
          {can("schedule") &&
            a.status !== "completed" &&
            a.status !== "cancelled" &&
            a.status !== "no_show" && (
              <button
                className="button small secondary"
                onClick={() =>
                  setAction({
                    title:
                      a.status === "scheduled"
                        ? "Check in"
                        : a.status === "checked_in"
                          ? "Start care"
                          : "Complete",
                    kind: "appointment.status",
                    fixed: {
                      id: a.id,
                      version: a.version,
                      status:
                        a.status === "scheduled"
                          ? "checked_in"
                          : a.status === "checked_in"
                            ? "in_care"
                            : "completed",
                    },
                    fields: [],
                  })
                }
              >
                {t(
                  a.status === "scheduled"
                    ? "Check in"
                    : a.status === "checked_in"
                      ? "Start care"
                      : "Complete",
                )}
              </button>
            )}
          {a.status === "scheduled" && (
            <button
              className="text-button danger"
              onClick={() =>
                setAction({
                  title: "Cancel",
                  kind: "appointment.status",
                  fixed: { id: a.id, version: a.version, status: "cancelled" },
                  fields: [text("reason", "Reason")],
                })
              }
            >
              {t("Cancel")}
            </button>
          )}
          {can("schedule") &&
            ["scheduled", "checked_in"].includes(String(a.status)) && (
              <button
                className="text-button"
                onClick={() =>
                  setAction({
                    title: "Reschedule appointment",
                    kind: "appointment.reschedule",
                    fixed: { id: a.id, version: a.version },
                    fields: [
                      {
                        name: "resource_id",
                        label: "Room / device",
                        value: a.resource_id,
                      },
                      {
                        name: "starts_at",
                        label: "Start",
                        type: "datetime-local",
                        required: true,
                      },
                      {
                        name: "ends_at",
                        label: "End",
                        type: "datetime-local",
                        required: true,
                      },
                      text("reason", "Reason"),
                    ],
                  })
                }
              >
                {t("Reschedule")}
              </button>
            )}
          {can("schedule") && a.status === "scheduled" && (
            <button
              className="text-button"
              onClick={() =>
                setAction({
                  title: "No-show",
                  kind: "appointment.status",
                  fixed: { id: a.id, version: a.version, status: "no_show" },
                  fields: [text("reason", "Reason")],
                })
              }
            >
              {t("No-show")}
            </button>
          )}
        </td>
      </tr>
    ));
  }
  function patientsTable(rows: Patient[]) {
    return rows.length ? (
      <DataTable
        heads={[
          "Patient",
          "Patient number",
          "Phone number",
          "Age",
          "Registered",
          "",
        ].map(t)}
      >
        {rows.map((p) => (
          <tr key={p.id}>
            <td>
              <button
                className="patient-link"
                onClick={() => navigate(`patients/${p.id}`)}
              >
                <span className="avatar">{p.full_name.slice(0, 1)}</span>
                <span className="strong" dir="auto">
                  {p.full_name}
                </span>
              </button>
            </td>
            <td className="mono">{p.patient_number}</td>
            <td dir="ltr">{p.phone ?? "—"}</td>
            <td>{ageAt(p.birth_date, p.birth_precision)}</td>
            <td>{formatDate(p.created_at, false, locale)}</td>
            <td>
              <button
                className="icon-button"
                aria-label={`${t("View")} ${p.full_name}`}
                onClick={() => navigate(`patients/${p.id}`)}
              >
                <ChevronRight size={17} />
              </button>
            </td>
          </tr>
        ))}
      </DataTable>
    ) : (
      <Empty
        t={t}
        text={search ? "No matching patients" : "Nothing here yet"}
      />
    );
  }
  let content: ReactNode;
  if (data.account?.password_change_required)
    content = (
      <AccountPanel
        t={t}
        onVerified={refresh}
        required
        onPasswordChanged={() =>
          setNotice(t("Password updated. Sign in with your new password."))
        }
      />
    );
  else if (!data.permissions.length)
    content = <MfaPanel t={t} onVerified={refresh} />;
  else if (selected)
    content = (
      <>
        <button
          className="text-button back"
          onClick={() => navigate("patients")}
        >
          {locale === "ckb" ? "→" : "←"} {t("Back to patients")}
        </button>
        <div className="patient-profile">
          <div className="profile-identity">
            <div className="avatar large">{selected.full_name.slice(0, 1)}</div>
            <div>
              <bdi className="eyebrow" dir="ltr">
                {selected.patient_number}
              </bdi>
              <h2 dir="auto">{selected.full_name}</h2>
              <p>
                {t("Age")}:{" "}
                {ageAt(selected.birth_date, selected.birth_precision)} ·{" "}
                <bdi dir="ltr">{selected.phone ?? t("No phone recorded")}</bdi>
              </p>
            </div>
          </div>
          <button
            className="button secondary"
            onClick={() => setAction(patientAction(selected))}
          >
            {t("Edit profile")}
          </button>
        </div>
        <div className="action-bar">
          {can("clinical") && (
            <>
              <button
                className="button secondary"
                onClick={() => setAction(consentAction(data, selected.id))}
              >
                {t("Record consent")}
              </button>
              <button
                className="button secondary"
                onClick={() => setAction(procedureAction(data, selected.id))}
              >
                {t("Record procedure")}
              </button>
            </>
          )}
          {can("billing") && (
            <>
              <button
                className="button secondary"
                onClick={() => setAction(invoiceAction(data, selected.id))}
              >
                {t("New invoice")}
              </button>
              <button
                className="button secondary"
                onClick={() => setAction(paymentAction(data))}
              >
                {t("Patient deposit")}
              </button>
            </>
          )}
          {can("approve") && (
            <button
              className="text-button danger"
              onClick={() =>
                setAction({
                  title: "Merge patient profiles",
                  kind: "patient.merge",
                  fixed: { patient_id: selected.id, version: selected.version },
                  fields: [
                    {
                      name: "target_id",
                      type: "patient",
                      label: "Surviving patient",
                      required: true,
                      options: options(
                        activePatients.filter((p) => p.id !== selected.id),
                        "full_name",
                      ),
                    },
                    {
                      ...text("reason", "Identity review evidence"),
                      type: "textarea",
                    },
                  ],
                })
              }
            >
              {t("Merge profile")}
            </button>
          )}
        </div>
        <nav className="patient-sections" aria-label={t("Patient sections")}>
          <div className="segmented">
            {[
              ...(can("clinical")
                ? [
                    { id: "records", label: "Clinical records" },
                    { id: "history", label: "Clinical history" },
                    { id: "documents", label: "Documents & consent" },
                  ]
                : []),
              ...(can("media")
                ? [{ id: "media", label: "Clinical media" }]
                : []),
              { id: "contacts", label: "Contacts" },
              { id: "access", label: "Care team & access" },
            ].map((section) => (
              <button
                key={section.id}
                className={patientSection === section.id ? "selected" : ""}
                aria-current={
                  patientSection === section.id ? "page" : undefined
                }
                onClick={() =>
                  setPatientView({ id: selected.id, section: section.id })
                }
              >
                {t(section.label)}
              </button>
            ))}
          </div>
        </nav>
        {can("clinical") && patientSection === "records" && (
          <section className="panel">
            <div className="panel-head">
              <h2>{t("Clinical records")}</h2>
              <span>{record?.encounters.length ?? "—"}</span>
            </div>
            {recordError ? (
              <ErrorMessage error={recordError} />
            ) : !record ? (
              <Loading t={t} />
            ) : !record.encounters.length ? (
              <Empty t={t} />
            ) : (
              record.encounters.map((e) => (
                <article className="encounter" key={e.id}>
                  <div className="encounter-head">
                    <div>
                      <span className="eyebrow">
                        {formatDate(e.created_at, true, locale)} ·{" "}
                        {doctorName(e.doctor_id)}
                      </span>
                      <h3>{str(e, "chief_complaint")}</h3>
                    </div>
                    <Badge status={e.status} t={t} />
                  </div>
                  <div className="clinical-grid">
                    {[
                      "history",
                      "allergies",
                      "findings",
                      "diagnosis",
                      "plan",
                      "prescriptions",
                    ].map((k, i) => (
                      <div key={k}>
                        <span className="eyebrow">
                          {t(
                            [
                              "History",
                              "Allergies",
                              "Findings",
                              "Diagnosis",
                              "Treatment plan",
                              "Prescriptions",
                            ][i],
                          )}
                        </span>
                        <p dir="auto">{str(e, k)}</p>
                      </div>
                    ))}
                  </div>
                  {Array.isArray(e.addenda) &&
                    e.addenda.map((a: Row) => (
                      <div className="addendum" key={a.id}>
                        <strong>
                          {t("Addendum")} ·{" "}
                          {formatDate(a.created_at, true, locale)}
                        </strong>
                        <p dir="auto">{String(a.content)}</p>
                      </div>
                    ))}
                  <div className="action-bar">
                    {e.status === "draft" && e.doctor_id === session.user.id ? (
                      <>
                        <button
                          className="button secondary small"
                          onClick={() =>
                            setAction(encounterAction(data, selected.id, e))
                          }
                        >
                          {t("Edit encounter")}
                        </button>
                        <button
                          className="button primary small"
                          onClick={() =>
                            setAction({
                              title: "Sign encounter",
                              kind: "encounter.sign",
                              fixed: { id: e.id, version: e.version },
                              fields: [],
                            })
                          }
                        >
                          <Check size={15} />
                          {t("Sign encounter")}
                        </button>
                      </>
                    ) : e.status === "signed" ? (
                      <button
                        className="button secondary small"
                        onClick={() =>
                          setAction({
                            title: "Add addendum",
                            kind: "encounter.addendum",
                            fixed: { encounter_id: e.id },
                            fields: [
                              {
                                ...text("content", "Addendum"),
                                type: "textarea",
                              },
                            ],
                          })
                        }
                      >
                        {t("Add addendum")}
                      </button>
                    ) : null}
                    <button
                      className="button secondary small"
                      onClick={() => window.print()}
                    >
                      {t("Print")}
                    </button>
                  </div>
                </article>
              ))
            )}
          </section>
        )}
        {can("media") && patientSection === "media" && (
          <MediaPanel
            key={`media-${session.user.id}-${selected.id}`}
            sessionKey={session.access_token}
            data={data}
            t={t}
            patientId={selected.id}
            onSaved={saved}
          />
        )}
        <PatientTools
          key={`tools-${session.user.id}-${selected.id}`}
          data={data}
          t={t}
          locale={locale}
          setAction={setAction}
          patient={selected}
          record={record}
          section={patientSection}
        />
      </>
    );
  else if (page === "overview")
    content = (
      <>
        <div className="welcome">
          <div>
            <span className="eyebrow">{t("Operational overview")}</span>
            <h2>{data.organization.name}</h2>
            <p>{formatDate(new Date().toISOString(), false, locale)}</p>
          </div>
        </div>
        <div className="metrics">
          {[
            {
              label: "Today’s appointments",
              visible: can("schedule"),
              value: data.metrics.today_appointments,
              icon: CalendarDays,
            },
            {
              label: "Waiting patients",
              visible: can("schedule"),
              value: data.metrics.waiting,
              icon: Users,
            },
            {
              label: "Open invoices",
              visible: can("billing") || can("finance"),
              value: data.metrics.open_invoices,
              icon: CircleDollarSign,
            },
            {
              label: "Follow-ups due",
              visible: can("results"),
              value: data.metrics.followups_due,
              icon: ClipboardList,
            },
          ]
            .filter((m) => m.visible)
            .map((m) => (
              <div className="metric" key={m.label}>
                <div className="metric-top">
                  <span>{t(m.label)}</span>
                  <m.icon size={18} />
                </div>
                <strong>{m.value}</strong>
                <span className="metric-note">
                  {t(m.label === "Today’s appointments" ? "Today" : "Current")}
                </span>
              </div>
            ))}
        </div>
        <nav className="quick-links" aria-label={t("Quick access")}>
          {navigation
            .filter(
              (n) =>
                [
                  "appointments",
                  "patients",
                  "clinical",
                  "billing",
                  "finance",
                  "accounting",
                  "inventory",
                ].includes(n.id) && can(n.permission),
            )
            .slice(0, 4)
            .map((n) => (
              <a key={n.id} className="quick-link" href={`#${n.id}`}>
                <n.icon size={20} />
                {t(n.label)}
              </a>
            ))}
        </nav>
        {can("schedule") && (
          <section className="panel">
            <div className="panel-head">
              <h2>
                {t("Today’s schedule")}
                <span className="count">{today.length}</span>
              </h2>
              <button
                className="text-button"
                onClick={() => navigate("appointments")}
              >
                {t("All appointments")} <ArrowRight size={15} />
              </button>
            </div>
            {today.length ? (
              <DataTable
                heads={[
                  "Time",
                  "Patient",
                  "Service",
                  "Clinician",
                  "Status",
                  "Action",
                ].map(t)}
              >
                {appointmentRows(today)}
              </DataTable>
            ) : (
              <Empty t={t} />
            )}
          </section>
        )}
        {can("patients") && (
          <section className="panel">
            <div className="panel-head">
              <h2>{t("Latest patients")}</h2>
              <button
                className="text-button"
                onClick={() => navigate("patients")}
              >
                {t("All patients")} <ArrowRight size={15} />
              </button>
            </div>
            {patientsTable(activePatients.slice(0, 5))}
          </section>
        )}
      </>
    );
  else if (page === "patients" && can("patients"))
    content = (
      <PatientDirectory
        t={t}
        refreshKey={data.patients}
        onSelect={(p) => {
          setData((d) =>
            d
              ? {
                  ...d,
                  patients: [...d.patients.filter((x) => x.id !== p.id), p],
                }
              : d,
          );
          navigate(`patients/${p.id}`);
        }}
      />
    );
  else if (page === "appointments" && can("schedule"))
    content = (
      <>
        <AppointmentsPage
          t={t}
          renderRows={appointmentRows}
          refreshKey={data.appointments}
        />
        <PhoneReminders
          data={data}
          t={t}
          locale={locale}
          setAction={setAction}
        />
        <ScheduleTools data={data} t={t} setAction={setAction} />
      </>
    );
  else if (page === "treatments" && can("schedule"))
    content = (
      <Treatments data={data} t={t} locale={locale} setAction={setAction} />
    );
  else if (page === "clinical" && can("clinical"))
    content = (
      <section className="panel">
        <div className="panel-head">
          <h2>{t("Clinical records")}</h2>
        </div>
        <RecordPager page={clinicalPage} t={t} />
        {clinicalPage.items.length ? (
          <DataTable
            heads={[
              "Patient",
              "Chief complaint",
              "Clinician",
              "Date",
              "Status",
              "Action",
            ].map(t)}
          >
            {clinicalPage.items.map((e) => (
              <tr key={e.id}>
                <td>{str(e, "patient_name")}</td>
                <td>{str(e, "chief_complaint")}</td>
                <td>{doctorName(e.doctor_id)}</td>
                <td>{formatDate(e.created_at, false, locale)}</td>
                <td>
                  <Badge t={t} status={e.status} />
                </td>
                <td>
                  <button
                    className="button small secondary"
                    onClick={() => navigate(`patients/${e.patient_id}`)}
                  >
                    {t("View")}
                  </button>
                </td>
              </tr>
            ))}
          </DataTable>
        ) : (
          <Empty t={t} />
        )}
      </section>
    );
  else if (page === "media" && can("media"))
    content = (
      <MediaPanel
        sessionKey={session.access_token}
        data={data}
        t={t}
        onSaved={saved}
      />
    );
  else if (page === "results" && can("results"))
    content = (
      <>
        <div className="action-bar">
          <button
            className="button secondary"
            onClick={() =>
              setAction({
                title: "New follow-up",
                kind: "task.create",
                fields: [
                  patient(data),
                  text("title", "Title"),
                  {
                    name: "due_at",
                    label: "Due date",
                    type: "datetime-local",
                    required: true,
                  },
                  {
                    name: "assigned_to",
                    label: "Assigned to",
                    required: true,
                    options: options(
                      data.members.filter(
                        (m) => hasRole(m, "doctor") && m.active,
                      ),
                      "display_name",
                      "user_id",
                    ),
                  },
                ],
              })
            }
          >
            <Plus size={16} />
            {t("New follow-up")}
          </button>
        </div>
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Results & follow-up")}</h2>
          </div>
          <RecordPager page={resultsPage} t={t} />
          {resultsPage.items.length ? (
            <DataTable
              heads={[
                "Patient",
                "Order name",
                "Specimen reference",
                "Due date",
                "Status",
                "Action",
              ].map(t)}
            >
              {resultsPage.items.map((r) => (
                <tr key={r.id}>
                  <td>{str(r, "patient_name")}</td>
                  <td>{str(r, "order_name")}</td>
                  <td className="mono">{str(r, "specimen_reference")}</td>
                  <td>{formatDate(r.due_at, false, locale)}</td>
                  <td>
                    <Badge status={r.status} t={t} />
                  </td>
                  <td>
                    {r.status !== "closed" && (
                      <button
                        className="button small secondary"
                        onClick={() =>
                          setAction({
                            title: "Record next step",
                            kind: "result.update",
                            fixed: {
                              id: r.id,
                              version: r.version,
                              status: (
                                {
                                  ordered: "received",
                                  received: "reviewed",
                                  reviewed: "notified",
                                  notified: "closed",
                                } as Record<string, string>
                              )[String(r.status)],
                            },
                            fields: [
                              {
                                ...text(
                                  "result_text",
                                  "Result / review / notification evidence",
                                ),
                                type: "textarea",
                              },
                            ],
                          })
                        }
                      >
                        {t("Record next step")}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} />
          )}
        </section>
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Follow-up")}</h2>
          </div>
          <RecordPager page={tasksPage} t={t} />
          {tasksPage.items.length ? (
            <DataTable
              heads={[
                "Patient",
                "Title",
                "Due date",
                "Assigned to",
                "Action",
              ].map(t)}
            >
              {tasksPage.items.map((r) => (
                <tr key={r.id}>
                  <td>{str(r, "patient_name")}</td>
                  <td>{str(r, "title")}</td>
                  <td>{formatDate(r.due_at, false, locale)}</td>
                  <td>{doctorName(r.assigned_to)}</td>
                  <td>
                    {r.completed_at ? (
                      <Badge status="completed" t={t} />
                    ) : (
                      <button
                        className="button small secondary"
                        onClick={() =>
                          setAction({
                            title: "Complete",
                            kind: "task.complete",
                            fixed: { id: r.id },
                            fields: [],
                          })
                        }
                      >
                        {t("Complete")}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} />
          )}
        </section>
      </>
    );
  else if (page === "billing" && can("billing"))
    content = (
      <Billing
        data={data}
        t={t}
        locale={locale}
        setAction={setAction}
        patientName={patientName}
        openInvoice={openInvoice}
        can={can}
      />
    );
  else if (page === "accounting" && can("finance"))
    content = (
      <Accounting
        data={data}
        t={t}
        locale={locale}
        setAction={setAction}
        onSaved={saved}
      />
    );
  else if (page === "finance" && can("finance"))
    content = (
      <Finance
        data={data}
        t={t}
        locale={locale}
        setAction={setAction}
        can={can}
      />
    );
  else if (page === "inventory" && (can("inventory") || can("inventory.read")))
    content = (
      <>
        <InventoryTools
          data={data}
          t={t}
          locale={locale}
          setAction={setAction}
        />
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Inventory")}</h2>
          </div>
          <RecordPager page={stockPage} t={t} />
          {stockPage.items.length ? (
            <DataTable
              heads={[
                "Product",
                "Lot number",
                "Expiry date",
                "Available",
                "Unit",
                "Action",
              ].map(t)}
            >
              {stockPage.items.map((s) => (
                <tr key={s.id}>
                  <td className="strong">{str(s, "product")}</td>
                  <td className="mono">{str(s, "lot_number")}</td>
                  <td
                    className={
                      String(s.expires_on) < day(new Date().toISOString())
                        ? "danger"
                        : ""
                    }
                  >
                    {formatDate(s.expires_on, false, locale)}
                  </td>
                  <td>{str(s, "quantity")}</td>
                  <td>{str(s, "unit")}</td>
                  <td>
                    {can("inventory") && (
                      <StockActions row={s} t={t} setAction={setAction} />
                    )}
                    {can("clinical") && (
                      <button
                        className="button small secondary"
                        onClick={() =>
                          setAction({
                            title: "Use stock",
                            kind: "stock.use",
                            fixed: { lot_id: s.id },
                            fields: [
                              patient(data),
                              encounter(data),
                              number("amount", "Quantity"),
                              text("reason", "Reason"),
                            ],
                          })
                        }
                      >
                        {t("Use stock")}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} />
          )}
        </section>
      </>
    );
  else if (page === "reports" && can("finance"))
    content = <Reports data={data} t={t} locale={locale} />;
  else if (page === "team" && can("staff"))
    content = <Team data={data} t={t} onSaved={saved} setAction={setAction} />;
  else if (page === "retention" && can("staff"))
    content = (
      <Retention data={data} t={t} locale={locale} setAction={setAction} />
    );
  else if (page === "settings" && can("settings"))
    content = (
      <>
        <ClinicalSharing data={data} t={t} setAction={setAction} />
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Settings")}</h2>
            <button
              className="button secondary"
              onClick={() =>
                setAction({
                  title: "Settings",
                  kind: "settings.update",
                  fields: [
                    text("name", "Clinic name", true, data.organization.name),
                    {
                      name: "require_mfa",
                      label: "Require MFA",
                      type: "checkbox",
                      value: data.organization.require_mfa,
                    },
                    {
                      name: "allow_cross_currency",
                      label: "Allow cross-currency settlement",
                      type: "checkbox",
                      value: data.organization.allow_cross_currency,
                    },
                  ],
                })
              }
            >
              {t("Edit profile")}
            </button>
          </div>
          <div className="settings-summary">
            <div>
              <span>{t("Clinic name")}</span>
              <strong>{data.organization.name}</strong>
            </div>
            <div>
              <span>Country / timezone</span>
              <strong>Iraq · Asia/Baghdad</strong>
            </div>
            <div>
              <span>{t("Currency")}</span>
              <strong>IQD + USD</strong>
            </div>
            <div>
              <span>{t("Security")}</span>
              <strong>
                {data.organization.require_mfa
                  ? "MFA required"
                  : "MFA optional"}
              </strong>
            </div>
          </div>
          <MfaPanel t={t} onVerified={refresh} />
        </section>
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Service")}</h2>
          </div>
          <DataTable
            heads={["Service", "Category", "Price", "Duration (minutes)"].map(
              t,
            )}
          >
            {data.services.map((s) => (
              <tr key={s.id}>
                <td>
                  {str(s, "name")}
                  <span className="cell-secondary" dir="auto">
                    {str(s, "name_ckb")}
                  </span>
                </td>
                <td>
                  {t(
                    str(s, "category").charAt(0).toUpperCase() +
                      str(s, "category").slice(1),
                  )}
                </td>
                <td>{money(s.price, s.currency as Currency, locale)}</td>
                <td>{str(s, "duration")}</td>
              </tr>
            ))}
          </DataTable>
        </section>
      </>
    );
  else if (page === "account")
    content = (
      <AccountPanel
        t={t}
        onVerified={refresh}
        onPasswordChanged={() =>
          setNotice(t("Password updated. Sign in with your new password."))
        }
      />
    );
  else if (page === "help") content = <Help locale={locale} t={t} />;
  else content = <Empty t={t} text="Access unavailable" />;
  return (
    <div
      className={`app-shell ${navigationOpen ? "navigation-open" : "navigation-closed"}`}
    >
      <a
        className="skip-link"
        href="#main-content"
        onClick={(event) => {
          event.preventDefault();
          document.getElementById("main-content")?.focus();
        }}
      >
        {t("Skip to content")}
      </a>
      <aside
        className="sidebar"
        id="workspace-navigation"
        inert={!navigationOpen}
        onKeyDown={(event) => {
          if (event.key === "Escape") {
            setNavigationOpen(false);
            document
              .querySelector<HTMLButtonElement>(
                'button[aria-controls="workspace-navigation"]',
              )
              ?.focus();
          }
        }}
      >
        <a href="#overview" className="brand">
          <span className="brand-mark">
            <Stethoscope size={24} />
          </span>
          <span>
            Clinic<span className="brand-os">OS</span>
            <small>{t("Dermatology")}</small>
          </span>
        </a>
        <div className="clinic-switch">
          <span className="clinic-initial">
            {data.organization.name.slice(0, 1)}
          </span>
          <div>
            <strong>{data.organization.name}</strong>
            <span>{t("Workspace")}</span>
          </div>
        </div>
        <nav aria-label={t("Workspace")}>
          {[
            {
              label: can("patients") || can("schedule") ? "Care" : "Workspace",
              ids: [
                "overview",
                "patients",
                "appointments",
                "treatments",
                "clinical",
                "media",
                "results",
              ],
            },
            {
              label: "Practice",
              ids: ["billing", "finance", "accounting", "inventory", "reports"],
            },
            { label: "Administration", ids: ["team", "settings", "retention"] },
            { label: "Help", ids: ["help"] },
          ].map((group) => {
            const items = navigation
              .filter((n) => group.ids.includes(n.id))
              .filter(
                (n) =>
                  !n.permission ||
                  can(n.permission) ||
                  (n.id === "inventory" && can("inventory.read")),
              );
            return (
              items.length > 0 && (
                <div className="nav-group" key={group.label}>
                  <span className="nav-label">{t(group.label)}</span>
                  {items.map((n) => (
                    <a
                      key={n.id}
                      href={`#${n.id}`}
                      className={`nav-item ${page === n.id ? "active" : ""}`}
                      aria-label={t(n.label)}
                      aria-current={page === n.id ? "page" : undefined}
                      onClick={() => {
                        if (window.innerWidth <= 760) setNavigationOpen(false);
                      }}
                    >
                      <n.icon size={19} strokeWidth={1.7} />
                      <span>{t(n.label)}</span>
                      {n.id === "appointments" && today.length > 0 && (
                        <span className="nav-count">{today.length}</span>
                      )}
                    </a>
                  ))}
                </div>
              )
            );
          })}
        </nav>
      </aside>
      {navigationOpen && (
        <button
          className="navigation-scrim"
          aria-label={t("Close navigation")}
          onClick={() => setNavigationOpen(false)}
        />
      )}
      <main id="main-content" tabIndex={-1}>
        <header className="topbar">
          <div className="breadcrumb">
            <button
              className="icon-button"
              aria-label={t("Toggle navigation")}
              aria-expanded={navigationOpen}
              aria-controls="workspace-navigation"
              onClick={() => setNavigationOpen(!navigationOpen)}
            >
              <PanelLeft size={19} />
            </button>
            <span>{t(heading)}</span>
          </div>
          <div className="topbar-actions">
            <button
              className="account-button"
              onClick={() => navigate("account")}
              aria-label={`${t("My account")}: ${data.membership.display_name}`}
            >
              <span className="avatar small" aria-hidden="true">
                {data.membership.display_name.slice(0, 1)}
              </span>
              <span className="account-name">
                {data.membership.display_name}
                <small>
                  {t(
                    data.membership.role.charAt(0).toUpperCase() +
                      data.membership.role.slice(1),
                  )}
                </small>
              </span>
            </button>
            <button className="locale-button" onClick={toggleLocale}>
              <Languages size={17} />
              {locale === "en" ? "کوردی" : "English"}
            </button>
            <button
              className="icon-button"
              aria-label={t("Refresh")}
              onClick={() => void refresh()}
              disabled={loading}
            >
              <RefreshCw size={17} className={loading ? "spin" : ""} />
            </button>
            <button
              className="icon-button"
              aria-label={t("Sign out")}
              title={t("Sign out")}
              onClick={() => void client().auth.signOut()}
            >
              <LogOut size={17} />
            </button>
          </div>
        </header>
        <div className="main-inner">
          <div className="page-heading">
            <div>
              <h1>{selected ? t("Patient profile") : t(heading)}</h1>
            </div>
            {primaryAction && data.permissions.length > 0 && (
              <button className="button primary" onClick={primaryAction}>
                <Plus size={17} />
                {t(primaryLabel)}
              </button>
            )}
          </div>
          {error && <ErrorMessage error={error} />}
          <div className="page-content">
            <Suspense fallback={<Loading t={t} />}>{content}</Suspense>
          </div>
          <footer className="workspace-footer">
            <span>ClinicOS · {t("Care")}</span>
            <span>IQD / USD · Asia/Baghdad</span>
          </footer>
        </div>
      </main>
      {action && (
        <CommandDialog
          key={`${action.kind}-${JSON.stringify(action.fixed)}`}
          action={action}
          data={data}
          t={t}
          onClose={() => setAction(null)}
          onSaved={saved}
        />
      )}
      <div className="toast-region" role="status" aria-live="polite">
        {notice && (
          <div className="toast">
            <Check size={17} />
            {notice}
          </div>
        )}
      </div>
    </div>
  );
}

function Login({
  t,
  toggleLocale,
  notice,
}: {
  t: T;
  toggleLocale: () => void;
  notice?: string;
}) {
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  return (
    <div className="login">
      <div className="login-story">
        <a className="brand" href="#">
          <span className="brand-mark">
            <Stethoscope />
          </span>
          ClinicOS
        </a>
        <div>
          <span className="eyebrow">{t("Dermatology")}</span>
          <h1>{t("Your clinic, in focus.")}</h1>
          <p>{t("A considered workspace for exceptional patient care.")}</p>
          <div className="login-art" aria-hidden="true">
            <div />
            <div />
            <div />
            <Stethoscope size={120} strokeWidth={0.8} />
          </div>
        </div>
        <span className="login-foot">
          {t("Medical & cosmetic dermatology")} · IQD / USD
        </span>
      </div>
      <div className="login-form">
        <button className="locale-button login-language" onClick={toggleLocale}>
          <Languages size={17} />
          English / کوردی
        </button>
        <div>
          <span className="eyebrow">CLINICOS WORKSPACE</span>
          <h2>{t("Sign in")}</h2>
          <p className="muted">{t("Use your individual clinic account.")}</p>
          {notice && <p role="status">{notice}</p>}
          {!configured ? (
            <ErrorMessage error="Supabase connection is not configured. Run npm run local:setup or configure .env.local." />
          ) : (
            <form
              onSubmit={async (e) => {
                e.preventDefault();
                const f = new FormData(e.currentTarget);
                setBusy(true);
                setError("");
                try {
                  const { error } = await client().auth.signInWithPassword({
                    email: usernameIdentity(String(f.get("username"))),
                    password: String(f.get("password")),
                  });
                  if (error) throw error;
                } catch (e) {
                  setError(e instanceof Error ? e.message : "Sign in failed");
                } finally {
                  setBusy(false);
                }
              }}
            >
              <label className="field">
                <span>{t("Username")}</span>
                <input
                  name="username"
                  type="text"
                  maxLength={32}
                  autoCapitalize="none"
                  spellCheck={false}
                  autoComplete="username"
                  required
                  dir="ltr"
                />
              </label>
              <div className="field">
                <label htmlFor="login-password">{t("Password")}</label>
                <div className="password-input">
                  <input
                    name="password"
                    id="login-password"
                    type={passwordVisible ? "text" : "password"}
                    autoComplete="current-password"
                    required
                    minLength={10}
                    dir="ltr"
                  />
                  <button
                    type="button"
                    aria-pressed={passwordVisible}
                    onClick={() => setPasswordVisible(!passwordVisible)}
                  >
                    {t(passwordVisible ? "Hide" : "Show")}
                  </button>
                </div>
              </div>
              {error && <ErrorMessage error={error} />}
              <button className="button primary full" disabled={busy}>
                {busy && <LoaderCircle size={16} className="spin" />}
                {t(busy ? "Signing in…" : "Sign in")}
                <ArrowRight size={17} />
              </button>
            </form>
          )}
          <p className="muted">
            {t(
              "Forgot your password? Ask your clinic administrator to reset it.",
            )}
          </p>
        </div>
      </div>
    </div>
  );
}
