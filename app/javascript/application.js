

// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import "popper"
import "bootstrap"
import "@hotwired/turbo-rails"
import "handsontable"
import "controllers"

// Test wie man eine Funktion zur Verfügung bringt
function myFunction(){
    return "x"
};
export default myFunction;
// Früher so:
//window.myFunction = myFunction

