import { useEffect, useState } from "react";
import type { Row, Snapshot, Locale } from "../domain/types";
import { RecordPager, useRecordPage } from "../components/RecordPager";
import { DataTable, ErrorMessage, type Action, type T } from "../components/ui";
import { text, number } from "./actions";
import { client } from "../lib/supabase";
import { formatDate, str } from "../lib/format";
export function InventoryTools({
  data,
  t,
  locale,
  setAction,
}: {
  data: Snapshot;
  t: T;
  locale: Locale;
  setAction: (a: Action) => void;
}) {
  const canWrite = data.permissions.includes("inventory"),
    products = useRecordPage("inventory_products", data),
    suppliers = useRecordPage("suppliers", canWrite ? data : null);
  const [rows, setRows] = useState<Row[]>([]),
    [error, setError] = useState(""),
    [expiryDays, setExpiryDays] = useState(30),
    [page, setPage] = useState(0),
    [more, setMore] = useState(false);
  useEffect(() => {
    let cancelled = false;
    setRows([]);
    setError("");
    void client()
      .rpc("inventory_alerts", { expiry_days: expiryDays, page_number: page })
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) setError(error.message);
        else {
          setRows(data.items);
          setMore(data.has_more);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [data, expiryDays, page]);
  return (
    <>
      <section className="panel">
        <div className="panel-head">
          <h2>{t("Stock alerts")}</h2>
          <label className="field">
            <span>{t("Expiry warning days")}</span>
            <input
              type="number"
              min={0}
              max={365}
              value={expiryDays}
              onChange={(e) => {
                const days = Number(e.target.value);
                if (Number.isInteger(days) && days >= 0 && days <= 365) {
                  setExpiryDays(days);
                  setPage(0);
                }
              }}
            />
          </label>
        </div>
        {error && <ErrorMessage error={error} />}
        <DataTable
          heads={[
            "Product",
            "Lot number",
            "Expiry date",
            "Available",
            "Reorder level",
            "Unit",
            "Status",
          ].map(t)}
        >
          {rows.map((row) => (
            <tr key={`${row.id}-${row.category}`}>
              <td>{str(row, "product")}</td>
              <td>{str(row, "lot_number")}</td>
              <td>{formatDate(row.expires_on, false, locale)}</td>
              <td>{str(row, "available")}</td>
              <td>{str(row, "threshold")}</td>
              <td>{str(row, "unit")}</td>
              <td>{t(str(row, "category"))}</td>
            </tr>
          ))}
        </DataTable>
        <div className="panel-head">
          <button
            className="button secondary"
            disabled={page === 0}
            onClick={() => setPage(page - 1)}
          >
            {t("Previous")}
          </button>
          <button
            className="button secondary"
            disabled={!more}
            onClick={() => setPage(page + 1)}
          >
            {t("Next")}
          </button>
        </div>
      </section>
      <details className="panel">
        <summary>{t("Product catalog")}</summary>
        {canWrite && (
          <div className="action-bar">
            <button
              className="button secondary"
              onClick={() =>
                setAction({
                  title: "Add inventory product",
                  kind: "product.create",
                  fields: [
                    text("name", "Product"),
                    text("unit", "Unit"),
                    {
                      ...number("reorder_level", "Reorder level", 0),
                      min: "0",
                    },
                    {
                      name: "supplier_id",
                      label: "Preferred supplier",
                      required: false,
                    },
                  ],
                })
              }
            >
              {t("Add inventory product")}
            </button>
          </div>
        )}
        <RecordPager page={products} t={t} />
        <DataTable
          heads={["Product", "Unit", "Reorder level", "Action"].map(t)}
        >
          {products.items.map((row) => (
            <tr key={row.id}>
              <td>{str(row, "name")}</td>
              <td>{str(row, "unit")}</td>
              <td>{str(row, "reorder_level")}</td>
              <td>
                {canWrite && (
                  <button
                    className="text-button"
                    onClick={() =>
                      setAction({
                        title: "Receive stock",
                        kind: "stock.receive",
                        fixed: {
                          product_id: row.id,
                          product: row.name,
                          unit: row.unit,
                        },
                        fields: [
                          text("lot_number", "Lot number"),
                          {
                            name: "expires_on",
                            label: "Expiry date",
                            type: "date",
                            required: true,
                          },
                          number("amount", "Quantity"),
                        ],
                      })
                    }
                  >
                    {t("Receive stock")}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </DataTable>
      </details>
      {canWrite && (
        <details className="panel">
          <summary>{t("Suppliers")}</summary>
          <div className="action-bar">
            <button
              className="button secondary"
              onClick={() =>
                setAction({
                  title: "Add supplier",
                  kind: "supplier.create",
                  fields: [
                    text("name", "Supplier / payee"),
                    text("contact_person", "Contact person", false),
                    text("phone", "Phone number", false),
                    text("address", "Address", false),
                  ],
                })
              }
            >
              {t("Add supplier")}
            </button>
          </div>
          <RecordPager page={suppliers} t={t} />
          <DataTable
            heads={[
              "Supplier / payee",
              "Contact person",
              "Phone number",
              "Address",
              "Action",
            ].map(t)}
          >
            {suppliers.items.map((row) => (
              <tr key={row.id}>
                <td>{str(row, "name")}</td>
                <td>{str(row, "contact_person")}</td>
                <td dir="ltr">{str(row, "phone")}</td>
                <td dir="auto">{str(row, "address")}</td>
                <td>
                  <button
                    className="text-button"
                    onClick={() =>
                      setAction({
                        title: "Edit supplier",
                        kind: "supplier.update",
                        fixed: { id: row.id, version: row.version },
                        fields: [
                          text("name", "Supplier / payee", true, row.name),
                          text(
                            "contact_person",
                            "Contact person",
                            false,
                            row.contact_person,
                          ),
                          text("phone", "Phone number", false, row.phone),
                          text("address", "Address", false, row.address),
                          {
                            name: "active",
                            label: "Active",
                            type: "checkbox",
                            value: row.active,
                          },
                        ],
                      })
                    }
                  >
                    {t("Edit profile")}
                  </button>
                </td>
              </tr>
            ))}
          </DataTable>
        </details>
      )}
    </>
  );
}
