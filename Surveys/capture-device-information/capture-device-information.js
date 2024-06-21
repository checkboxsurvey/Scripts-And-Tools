(function() {
    // Set a variable for each question this script will answer.
    const userAgentField = document.querySelector('.user-agent-capture input');
    
    // The field could have been set by a default value from a Profile Property.
    let prevUserAgent = userAgentField.value;

    function captureUserAgent() {
        let currUserAgent = navigator.userAgent;

        if (currUserAgent) {

            if (prevUserAgent !== currUserAgent) {

                // Set the value and hide the field from the user.
                userAgentField.value = currUserAgent;
                userAgentField.readOnly = true;
                userAgentField.hidden = true;
                
                // Checkbox Frontend uses Angular, we need to force a DOM re-render.
                userAgentField.dispatchEvent(new Event('input', { 'bubbles': true, 'cancelable': false }));
            }

            prevUserAgent = currUserAgent;

        }
    }

    setTimeout(captureUserAgent, 200);
    
})();