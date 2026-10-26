import type { Locale } from "../domain/types";
import type { T } from "../components/ui";
import english from "../../docs/user-guide.md?raw";
import sorani from "../../docs/user-guide.ckb.md?raw";
import { downloadFile } from "../lib/download";
const plain = (value: string) =>
  value
    .replace(/\*\*(.*?)\*\*/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/`([^`]+)`/g, "$1");
export function Help({ locale, t }: { locale: Locale; t: T }) {
  const guide = locale === "ckb" ? sorani : english;
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Help & user guide")}</h2>
        <button
          className="button secondary"
          onClick={() =>
            downloadFile(
              `ClinicOS-guide-${locale}.md`,
              guide,
              "text/markdown;charset=utf-8",
            )
          }
        >
          {t("Download staff guide")}
        </button>
      </div>
      <article className="staff-guide">
        {guide
          .trim()
          .split(/\n\n+/)
          .map((block, index) => {
            const lines = block.split("\n");
            if (block.startsWith("# "))
              return <h2 key={index}>{plain(block.slice(2))}</h2>;
            if (block.startsWith("### "))
              return <h4 key={index}>{plain(block.slice(4))}</h4>;
            if (block.startsWith("## "))
              return <h3 key={index}>{plain(block.slice(3))}</h3>;
            if (block.startsWith("|")) {
              const rows = lines
                .filter((line) => !/^\|[\s:|\-]+\|$/.test(line))
                .map((line) =>
                  line
                    .split("|")
                    .slice(1, -1)
                    .map((cell) => plain(cell.trim())),
                );
              return (
                <div className="table-wrap" key={index}>
                  <table>
                    <thead>
                      <tr>
                        {rows[0].map((cell, i) => (
                          <th key={i}>{cell}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {rows.slice(1).map((row, i) => (
                        <tr key={i}>
                          {row.map((cell, j) => (
                            <td key={j}>{cell}</td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              );
            }
            if (/^\d+\. /.test(block))
              return (
                <ol key={index}>
                  {lines.map((line, i) => (
                    <li key={i}>{plain(line.replace(/^\d+\. /, ""))}</li>
                  ))}
                </ol>
              );
            if (block.startsWith("- "))
              return (
                <ul key={index}>
                  {lines.map((line, i) => (
                    <li key={i}>{plain(line.replace(/^- /, ""))}</li>
                  ))}
                </ul>
              );
            return <p key={index}>{plain(block)}</p>;
          })}
      </article>
    </section>
  );
}
