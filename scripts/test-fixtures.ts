/** Harmless EICAR signature inside a valid PDF attachment exercises recursive scanning. */
export function antivirusPdf(): Uint8Array {
  const signature = String.raw`X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*`;
  const objects = [
    "<</Type /Catalog /Names <</EmbeddedFiles <</Names [(antivirus-test.com) 3 0 R]>>>>>>",
    `<</Type /EmbeddedFile /Length ${signature.length}>>\nstream\n${signature}\nendstream`,
    "<</Type /Filespec /F (antivirus-test.com) /EF <</F 2 0 R>>>>",
  ];
  let pdf = "%PDF-1.7\n";
  const offsets: number[] = [];
  objects.forEach((object, index) => {
    offsets.push(pdf.length);
    pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = pdf.length;
  pdf +=
    "xref\n0 4\n0000000000 65535 f \n" +
    offsets.map((n) => `${String(n).padStart(10, "0")} 00000 n \n`).join("");
  pdf += `trailer\n<</Size 4 /Root 1 0 R>>\nstartxref\n${xref}\n%%EOF\n`;
  return new TextEncoder().encode(pdf);
}
