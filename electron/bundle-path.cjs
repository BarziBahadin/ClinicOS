const path = require("node:path");
function bundlePath(root, rawUrl, method = "GET") {
  try {
    const url = new URL(rawUrl);
    if (
      url.protocol !== "clinicos:" ||
      url.host !== "app" ||
      url.username ||
      url.password ||
      !["GET", "HEAD"].includes(method)
    )
      return null;
    const pathname = decodeURIComponent(url.pathname);
    if (
      pathname.includes("\0") ||
      pathname.includes("\\") ||
      !(
        pathname === "/index.html" ||
        pathname === "/" ||
        pathname.startsWith("/assets/")
      )
    )
      return null;
    const file = path.resolve(
      root,
      "." + (pathname === "/" ? "/index.html" : pathname),
    );
    const relative = path.relative(root, file);
    return relative && !relative.startsWith("..") && !path.isAbsolute(relative)
      ? file
      : null;
  } catch {
    return null;
  }
}
module.exports = { bundlePath };
