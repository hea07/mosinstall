<?php
$catalogUrl = 'https://swscan.apple.com/content/catalogs/others/index-12-1.sucatalog';

$searchIApkg = 'InstallAssistant.pkg';

$catalogContent = file_get_contents($catalogUrl);

if ($catalogContent !== false) {

    $lines = explode("\n", $catalogContent);

    $lastMatchedLine = '';

    // URL of the remote XML file
    $xmlUrl = 'https://swscan.apple.com/content/catalogs/others/index-12-1.sucatalog';

    // Fetch the XML content using file_get_contents
    $xmlData = file_get_contents($xmlUrl);

    // Check if fetching the content was successful
    if ($xmlData === false) {
        echo 'Failed to fetch the XML file.';
        exit;
    }

    // Load the XML string
    $doc = new DOMDocument();
    $doc->loadXML($xmlData);

    // Find the URL
    $xpath = new DOMXPath($doc);
    $url = $xpath->query('/plist/dict/dict/dict[18]/dict[2]/string')->item(0)->nodeValue;

    // echo $url;

    // XPath for the Versionnumber
    // /installer-gui-script[@minSpecVersion="2"]/auxinfo/dict//string[2]/text()

    // Fetch the XML content using file_get_contents
    $VersxmlData = file_get_contents($url);

    // Check if fetching the content was successful
    if ($VersxmlData === false) {
        echo 'Failed to fetch the XML file.';
        exit;
    }

    // Load the XML string
    $versdoc = new DOMDocument();
    $versdoc->loadXML($VersxmlData);

    // Find the URL
    $xpathv = new DOMXPath($versdoc);
    $ProductVersion = $xpathv->query('/installer-gui-script[@minSpecVersion="2"]/auxinfo/dict//string[2]/text()')->item(0)->nodeValue;

    //echo $versn;

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

    $venturaLink = $lastMatchedLine;
    $venturaVersion = $ProductVersion;

    echo "$venturaVersion|||$venturaLink";
} else {
    echo "Unable to retrieve content from the external URL.";
}
