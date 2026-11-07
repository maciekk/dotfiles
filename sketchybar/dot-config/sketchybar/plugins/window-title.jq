# AeroSpace returns an array containing the focused window, or an empty array.
.[0] |
if . == null then "Desktop"
else
  .["app-name"] as $app |
  (.["window-title"] // "") as $raw |
  # Obsidian: document - vault - Obsidian version. Strip from the right so
  # document names containing " - " remain intact. Leave unknown formats alone.
  ($raw | split(" - ")) as $parts |
  (if $app == "Obsidian" and ($parts | length) >= 3 and
      ($parts[-1] | test("^Obsidian [0-9]+\\.[0-9]+"))
   then $parts[0:-2] | join(" - ")
   else $raw end) as $document |
  $app + (if $document == "" then "" else " — " + $document end)
end |
gsub("[\r\n\t]"; " ") |
if length > 55 then .[0:54] + "…" else . end
