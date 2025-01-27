<script lang="ts">
  import { onMount } from "svelte";
  import mermaid from "mermaid";
  import { GoogleGenerativeAI, type Part } from "@google/generative-ai";

  let code = `graph TD
    A[Start] --> B{Is it?}
    B -- Yes --> C[OK]
    C --> D[Rethink]
    D --> B
    B -- No ----> E[End]`;
  let mermaidSvg = "";
  let accessToken = "";
  let isValidToken = false;
  let inputText = "";
  let attachedFile: File | null = null;
  let isProcessing = false;

  const MODEL_NAME = "gemini-2.0-flash-exp";

  onMount(() => {
    mermaid.initialize({ startOnLoad: true });
    updateMermaid();
  });

  const validateMermaid = async (code: string) => {
    try {
      await mermaid.parse(code);
      return true;
    } catch (error) {
      console.error("Mermaid validation error:", error);
      return false;
    }
  };

  const updateMermaid = async () => {
    if (await validateMermaid(code)) {
      try {
        const { svg } = await mermaid.render("mermaid-graph", code);
        mermaidSvg = svg;
      } catch (error) {
        console.error("Mermaid rendering error:", error);
        mermaidSvg = "Error rendering Mermaid diagram";
      }
    } else {
      mermaidSvg = "Invalid Mermaid syntax";
    }
  };

  const generatePrompt = (
    inputText: string,
    code: string,
    fileDisplayName?: string
  ) => {
    let prompt = `
      You are a Mermaid code generator.
      Please convert the following input into Mermaid code:

      "${inputText}"
    `;

    if (fileDisplayName) {
      prompt += `
        Please also consider the content of the attached file: ${fileDisplayName}
      `;
    }

    prompt += `
      Please ensure the output is a valid Mermaid diagram.

      Current code:
      \`\`\`mermaid
      ${code}
      \`\`\`

      Output only the Mermaid code and nothing else.
    `;

    return prompt;
  };

  const analyseResponse = (response: string) => {
    const bracketedContent = response.match(/`mermaid\n([\s\S]+)\n`/);
    if (bracketedContent) {
      response = bracketedContent[1];
    }
    return response;
  };

  const getGenAIModel = () => {
    if (!accessToken) {
      throw new Error("Access token is required.");
    }
    const genAI = new GoogleGenerativeAI(accessToken);
    return genAI.getGenerativeModel({ model: MODEL_NAME });
  };

  const countToken = async () => {
    try {
      const model = getGenAIModel();
      let prompt = "";

      if (attachedFile && attachedFile.type === "text/plain") {
        const textContent = await attachedFile.text();
        prompt = generatePrompt(
          `Here is the content of the text file "${attachedFile.name}":\n\n${textContent}\n\n` +
            inputText,
          code
        );
      } else if (attachedFile) {
        // NOTE: 現状、この部分は実行されません。
        // Part を含むと countTokens でエラーが発生します。
        const fileData = await fileToGenerativePart(attachedFile);
        prompt = generatePrompt(inputText, code, attachedFile.name);
      } else {
        prompt = generatePrompt(inputText, code);
      }

      const result = await model.countTokens(prompt);

      isValidToken = result.totalTokens > 0;
      alert(`Total tokens: ${result.totalTokens}`);
    } catch (error) {
      console.error("Error verifying token:", error);
      isValidToken = false;
    }
  };

  const sendToLLM = async (prompt: string, fileData?: Part) => {
    isProcessing = true;
    try {
      const model = getGenAIModel();
      const result = await model.generateContent(
        fileData ? [prompt, fileData] : prompt
      );

      code = analyseResponse(result.response.text());
      await updateMermaid();
      inputText = "";
    } catch (error) {
      console.error("Error sending to LLM:", error);
      throw error; // エラーを上位に伝播させる
    } finally {
      isProcessing = false;
    }
  };

  const uploadFileAndSendToLLM = async () => {
    if (!attachedFile) {
      alert("Please attach a file.");
      return;
    }

    isProcessing = true;
    try {
      const model = getGenAIModel();

      if (attachedFile.type === "text/plain") {
        // テキストファイルの場合は内容を読み込む
        const textContent = await attachedFile.text();

        const prompt = generatePrompt(
          `Here is the content of the text file "${attachedFile.name}":\n\n${textContent}\n\n` +
            inputText,
          code
        );

        // テキストファイルの内容をプロンプトに含めて送信
        await sendToLLM(prompt);
      } else {
        // 他のファイルタイプの場合は従来通りファイルを添付
        const fileData = await fileToGenerativePart(attachedFile);
        const prompt = generatePrompt(
          "Transcribe the first few sentences of this document.",
          code,
          attachedFile.name
        );
        await sendToLLM(prompt, fileData);
      }
    } catch (error) {
      console.error("Error sending file to LLM:", error);
    } finally {
      isProcessing = false;
    }
  };

  const handleSendToLLM = async () => {
    isProcessing = true;
    try {
      if (attachedFile) {
        // ファイルが添付されている場合
        if (attachedFile.type === "text/plain") {
          // テキストファイルの場合は内容を読み込む
          const textContent = await attachedFile.text();
          const prompt = generatePrompt(
            `Here is the content of the text file "${attachedFile.name}":\n\n${textContent}\n\n` +
              inputText,
            code
          );
          await sendToLLM(prompt);
        } else {
          // 他のファイルタイプの場合はファイルを Part オブジェクトに変換
          const fileData = await fileToGenerativePart(attachedFile);
          const prompt = generatePrompt(
            "Transcribe the first few sentences of this document.",
            code,
            attachedFile.name
          );
          await sendToLLM(prompt, fileData);
        }
      } else {
        const prompt = generatePrompt(inputText, code);
        await sendToLLM(prompt);
      }
    } catch (error) {
      console.error("Error sending to LLM:", error);
    } finally {
      isProcessing = false;
    }
  };

  const handleExportCode = async () => {
    try {
      await navigator.clipboard.writeText(code);
      alert("Mermaid code copied to clipboard!");
    } catch (err) {
      console.error("Failed to copy:", err);
    }
  };

  const handleShareToX = () => {
    const MAX_LENGTH = 250;
    let text = "Generated by Mermaid editor:\n`mermaid\n" + code + "\n`";
    if (inputText) {
      text = inputText + "\n" + text;
    }

    if (text.length > MAX_LENGTH) {
      text = text.substring(0, MAX_LENGTH - 3) + "...";
    }

    const url = `https://twitter.com/intent/tweet?text=${encodeURIComponent(
      text
    )}&hashtags=MermaidEditor`;
    window.open(url, "_blank");
  };

  const handleAttachFile = (event: Event) => {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      attachedFile = input.files[0];
      if (attachedFile.type !== "text/plain") {
        alert("Only .txt files can be attached for direct content inclusion.");
      }
    }
  };

  async function fileToGenerativePart(file: File): Promise<Part> {
    const base64EncodedDataPromise = new Promise<string>((resolve) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve((reader.result as string).split(",")[1]);
      reader.readAsDataURL(file);
    });

    return {
      inlineData: {
        data: await base64EncodedDataPromise,
        mimeType: file.type,
      },
    };
  }
</script>

<header class="header">
  <input
    type="password"
    bind:value={accessToken}
    placeholder="Enter access token (hidden)"
    autocomplete="on"
  />
  <button on:click={countToken} disabled={isProcessing}>Count Token</button>
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
  <button on:click={handleSendToLLM} disabled={isProcessing}>Send to LLM</button
  >
  <input
    type="file"
    id="fileInput"
    accept=".txt"
    style="display: none;"
    on:change={handleAttachFile}
  />
  <button
    on:click={() => {
      document.getElementById("fileInput")?.click();
    }}
    disabled={isProcessing}
  >
    Attach File
  </button>
  <button on:click={handleExportCode} disabled={isProcessing}>Export</button>
  <button on:click={handleShareToX} disabled={isProcessing}
    >Share to X.com</button
  >
</header>

<main class="content">
  <div class="editor">
    <textarea bind:value={code} on:input={updateMermaid}></textarea>
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
