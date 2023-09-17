<?php
//write code that opens the last link to ExtendedMetaInfo file of the sucatalog and then searches for the version key.
$catalogUrl = 'https://swscan.apple.com/content/catalogs/others/index-12-1.sucatalog';

$searchIApkg = 'InstallAssistant.pkg';

$catalogContent = file_get_contents($catalogUrl);

if ($catalogContent !== false) {

    $lines = explode("\n", $catalogContent);

    $lastMatchedLine = '';

	$lastValue = null; // Initialize a variable to store the last found value
    $pattern = '/https:\/\/swdist\.apple\.com\/content\/downloads\/\d+\/\d+\/\S+\/\S+\/\d{3}-\d+\.\w+\.dist/gm';

    // Iterate through the matches and update $lastValue each time
    preg_match_all($pattern, $catalogContent, $matches);

    if (!empty($matches[1])) {
        $lastValue = end($matches[1]); // Get the last matched value
        echo $lastValue;
    } else {
        echo 'Key "Bamhbus" not found.';
    }

    // Iterate through the lines in reverse order
    for ($i = count($lines) - 1; $i >= 0; $i--) {
        // Check if the line contains the search word
        if (strpos($lines[$i], $searchIApkg) !== false) {
            $lastMatchedLine = $lines[$i];
            break; // Stop searching after finding the last occurrence
        }
    }

    // Output the last matched line
    if (!empty($lastMatchedLine)) {
        //echo "$lastMatchedLine";
    } else {
        echo "No match found for '$searchIApkg' in the external file content.";
    }

    $montereyLink = $lastMatchedLine;
    $montereyVersion = $ProductVersion;

    echo "$montereyVersion|||$montereyLink";
} else {
    echo "Unable to retrieve content from the external URL.";
}
?>