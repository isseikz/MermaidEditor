<script lang="ts">
  import { onMount } from "svelte";
  import mermaid from "mermaid";
  import { GoogleGenerativeAI } from "@google/generative-ai";

  let code = `graph TD
    A[Start] --> B{Is it?}
    B -- Yes --> C[OK]
    C --> D[Rethink]
    D --> B
    B -- No ----> E[End]`;
  let mermaidSvg = "";
  let accessToken = "";
  let isValidToken = false;
  let inputText = ""; // 入力された文章を格納する変数

  onMount(() => {
    mermaid.initialize({ startOnLoad: false });
    updateMermaid();
  });

  $: {
    if (code) {
      updateMermaid();
    }
  }

  const updateMermaid = async () => {
    try {
      const { svg } = await mermaid.render("mermaid-graph", code);
      mermaidSvg = svg;
    } catch (error) {
      console.error("Mermaid rendering error:", error);
      mermaidSvg = "Error rendering Mermaid diagram";
    }
  };

  const generatePrompt = (inputText: string, code: string) => {
    return `
      You are a Mermaid code generator.
      Please convert the following input into Mermaid code:
      
      "${inputText}"

      Please ensure the output is a valid Mermaid diagram.
      
      Current code:
      \`\`\`mermaid
      ${code}
      \`\`\`

      Output only the Mermaid code and nothing else.
    `;
  };

  const analyseResponse = (response: string) => {
    // Analyse the response and update the Mermaid code

    // If the response is bracketed with ```, extract the content
    const bracketedContent = response.match(/```mermaid\n([\s\S]+)\n```/);
    if (bracketedContent) {
      response = bracketedContent[1];
    }

    return response;
  };

  const countToken = async () => {
    if (!accessToken) {
      isValidToken = false;
      return;
    }

    if (!inputText) {
      alert("Please enter some text.");
      return;
    }

    try {
      // Gemini API を使用してトークンを検証 (仮の実装)
      const genAI = new GoogleGenerativeAI(accessToken);
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash-exp",
      });

      const prompt = generatePrompt(inputText, code);
      const result = await model.countTokens(prompt);

      result.totalTokens > 0 ? (isValidToken = true) : (isValidToken = false);
    } catch (error) {
      console.error("Error verifying token:", error);
      isValidToken = false;
    }
  };

  const sendToLLM = async () => {
    if (!inputText) {
      alert("Please enter some text.");
      return;
    }

    const prompt = generatePrompt(inputText, code);

    try {
      // Gemini API を使用してトークンを検証 (仮の実装)
      const genAI = new GoogleGenerativeAI(accessToken);
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash-exp",
      });

      const prompt = generatePrompt(inputText, code);
      const result = await model.generateContent(prompt);

      code = analyseResponse(result.response.text());
      updateMermaid();
      inputText = ""; // 入力フォームをクリア
    } catch (error) {
      console.error("Error sending to LLM:", error);
    }
  };
</script>

<header class="header">
  <input
    type="text"
    bind:value={accessToken}
    placeholder="Enter access token"
  />
  <button on:click={countToken}>Count Token</button>
  {#if isValidToken}
    <span class="valid-token">Valid Token</span>
  {:else}
    <span class="invalid-token">Invalid Token</span>
  {/if}
  <input
    type="text"
    bind:value={inputText}
    placeholder="Enter text to convert"
  />
  <button on:click={sendToLLM}>Send to LLM</button>
</header>

<main class="content">
  <div class="editor">
    <textarea bind:value={code} />
  </div>
  <div class="preview">
    {@html mermaidSvg}
  </div>
</main>

<style>
  .header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px;
    border-bottom: 1px solid #ccc;
  }

  .valid-token {
    color: green;
  }

  .invalid-token {
    color: red;
  }

  .content {
    display: flex;
    height: calc(100vh - 50px); /* Adjust height based on header height */
  }

  .editor {
    width: 50%;
    padding: 10px;
  }

  .editor textarea {
    width: 100%;
    height: 100%;
    resize: none;
    border: 1px solid #ccc;
    font-family: "Courier New", Courier, monospace;
  }

  .preview {
    width: 50%;
    padding: 10px;
    border-left: 1px solid #ccc;
    overflow: auto;
  }
</style>
