<script>
  let importedText = "";

  const importFile = (event) => {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        importedText = e.target.result;
        console.log("Imported text:", importedText);
      };
      reader.readAsText(file);
    }
  };

  const copyToClipboard = () => {
    if (importedText) {
      navigator.clipboard.writeText(importedText)
        .then(() => {
          alert("Text copied to clipboard!");
        })
        .catch(err => {
          console.error("Failed to copy text:", err);
        });
    } else {
      alert("No text imported yet.");
    }
  };
</script>

<style>
  body {
    font-family: sans-serif;
  }
  button {
    padding: 10px 20px;
    margin: 10px;
    background-color: #4CAF50;
    color: white;
    border: none;
    cursor: pointer;
  }
</style>

<button on:click={() => document.getElementById('fileInput').click()}>Import .txt</button>
<button on:click={copyToClipboard}>Copy to Clipboard</button>

<input type="file" id="fileInput" accept=".txt" style="display: none;" on:change={importFile}>
