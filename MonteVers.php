<?php
$distFileUrl = 'https://swscan.apple.com/content/catalogs/others/index-12-1.sucatalog'; // Replace with your .dist file URL

$distContent = file_get_contents($distFileUrl);

if ($distContent !== false) {
    // Create an array to store matches
    $matches = [];
    
    // Split the content into lines and iterate through them
    $lines = explode("\n", $distContent);
    
    foreach ($lines as $line) {
        // Check if the line contains the key "Bambus"
        if (strpos($line, 'key: Bambus') !== false) {
            // If found, add the line to the matches array
            $matches[] = $line;
        }
    }
    
    // Check if there were any matches
    if (!empty($matches)) {
        // Get the last match from the array
        $lastMatch = end($matches);
        
        // Extract the corresponding value
        if (preg_match('/string: (.+)/', $lastMatch, $valueMatches)) {
            $lastValue = $valueMatches[1];
            echo $lastValue;
        } else {
            echo 'Value not found for the last occurrence of "Bambus".';
        }
    } else {
        echo 'Key "Bambus" not found.';
    }
} else {
    echo 'Failed to fetch .dist file content.';
}
?>
