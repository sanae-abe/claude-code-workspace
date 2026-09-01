// Test file with XSS vulnerabilities
function displayUserInput(input) {
  document.getElementById("output").innerHTML = input;
}

function writeContent(content) {
  document.write(content);
}

function evaluateCode(code) {
  eval(code);
}

// React component with unsafe HTML
const UnsafeComponent = ({ userContent }) => {
  return (
    <div dangerouslySetInnerHTML={{ __html: userContent }} />
  );
};
