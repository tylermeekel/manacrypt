export function downloadObjectAsJson(jsonString, exportName) {
  var dataStr =
    "data:text/json;charset=utf-8," + encodeURIComponent(jsonString);
  var downloadAnchorNode = document.createElement("a");
  downloadAnchorNode.setAttribute("href", dataStr);
  downloadAnchorNode.setAttribute("download", exportName + ".json");
  document.body.appendChild(downloadAnchorNode); // required for firefox
  downloadAnchorNode.click();
  downloadAnchorNode.remove();
}
