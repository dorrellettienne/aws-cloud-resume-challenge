const counter = document.querySelector("#counter-value");
const counterUrl = window.CLOUD_RESUME_CONFIG?.counterUrl?.trim();

async function updateCounter() {
    if (!counterUrl) {
        counter.textContent = "Available when deployed";
        return;
    }

    try {
        const response = await fetch(counterUrl, {
            method: "GET",
            headers: { Accept: "application/json" }
        });

        if (!response.ok) {
            throw new Error(`Counter request failed with ${response.status}`);
        }

        const data = await response.json();
        const views = typeof data === "number" ? data : data.views;

        if (!Number.isInteger(views)) {
            throw new Error("Counter response did not include an integer");
        }

        counter.textContent = views.toLocaleString("en-GB");
    } catch (error) {
        console.error("Unable to load visitor count", error);
        counter.textContent = "Temporarily unavailable";
    }
}

updateCounter();
