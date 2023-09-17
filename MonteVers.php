<?php
$distFileUrl = 'https://swscan.apple.com/content/catalogs/others/index-12-1.sucatalog'; // Replace with your .dist file URL

$distContent = file_get_contents($distFileUrl);

if ($distContent !== false) {
    $lastValue = null; // Initialize a variable to store the last found value
    $pattern = '/key\s*:\s*ExtendedMetaInfo\s*\n\s*string\s*:\s*(.*?)\s*\n/s';

    // Iterate through the matches and update $lastValue each time
    preg_match_all($pattern, $distContent, $matches);

    if (!empty($matches[1])) {
        $lastValue = end($matches[1]); // Get the last matched value
        echo $lastValue;
    } else {
        echo 'Key "Bambus" not found.';
    }
} else {
    echo 'Failed to fetch .dist file content.';
}
?>
