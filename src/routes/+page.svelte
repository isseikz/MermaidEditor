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

  const MODEL_NAME = "gemini-2.0-flash-thinking-exp-01-21";

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

    prompt += `
    ## How to write Mermaid code
    ### Class Diagram

    Mermaid is a Javascript-based diagramming and charting tool that uses Markdown-inspired text definitions and a renderer to display them in browsers.

    Follow these guidelines when generating Mermaid code:

    **1. Diagram Types and Syntax:**

    *   **Flowchart:**  Use nodes (shapes) and edges (arrows) to represent steps and flow in a process. Refer to: [Mermaid Flowchart Syntax](https://mermaid.js.org/syntax/flowchart.html)
        *   Nodes shapes: square, circle, stadium, subroutine, cylinder, ellipse, diamond, hexagon, parallelogram, trapezoid, double circle
        *   Edge types: arrows (-->), open arrows (---), dotted arrows (.->), thick arrows (==>), line styles (e.g., \`style id fill:#f9f,stroke:#333,stroke-width:2px\`)
        *   Subgraphs: \`subgraph title ... end\`
        *   Direction: \`direction LR/RL/TB/BT\`

    *   **Sequence Diagram:** Illustrate interactions between actors in a time-based sequence. Refer to: [Mermaid Sequence Diagram Syntax](https://mermaid.js.org/syntax/sequenceDiagram.html)
        *   Participants: \`participant\`, \`actor\`
        *   Messages: \`->\` (solid arrow), \`-->\` (dashed arrow), \`-x\` (solid cross), \`--x\` (dashed cross), \`->>\` (solid open arrow), \`-->>\` (dashed open arrow), \`o->\` (solid circle), \`o-->\` (dashed circle)
        *   Activations: \`activate\`, \`deactivate\`
        *   Notes: \`Note left of/right of/over participant: text\`
        *   Loops: \`loop text ... end\`
        *   Alts/Options: \`alt text ... else text ... end\`, \`opt text ... end\`
        *   Parallel: \`par ... and ... end\`

    *   **Class Diagram:**  Describe the structure of classes, their attributes, and methods, and relationships between classes. Refer to: [Mermaid Class Diagram Syntax](https://mermaid.js.org/syntax/classDiagram.html)
        *   Classes: \`class ClassName\`
        *   Properties/Attributes: inside class definition
        *   Methods/Operations: inside class definition with parentheses \`()\`
        *   Relationships:
            *   Association: \`--\`
            *   Directed Association: \`-->\`
            *   Aggregation: \`o--\`
            *   Composition: \`*--\`
            *   Dependency: \`..>\`
            *   Inheritance/Generalization: \`--|>\`
            *   Realization/Interface: \`..|>\`
        *   Annotations: \`<<Interface>>\`, \`<<enumeration>>\`

    *   **State Diagram:** Model the states of a system, transitions between states, and events that trigger transitions. Refer to: [Mermaid State Diagram Syntax](https://mermaid.js.org/syntax/stateDiagram.html)
        *   States: \`state StateName\`
        *   Transitions: \`State1 --> State2 : event\`
        *   State Types:
            *   Initial state: \`[*] --> State\`
            *   Final state: \`State --> [*]\`
            *   Composite states: \`state CompositeState { ... }\`
            *   Fork/Join: \`[*] --> State1 & State2\`, \`State1 & State2 --> [*]\`
        *   Notes: \`note left of/right of/over State: text\`

    *   **Entity Relationship Diagram (ERD):**  Represent the logical structure of data in a system, showing entities and relationships between them. Refer to: [Mermaid Entity Relationship Diagram Syntax](https://mermaid.js.org/syntax/entityRelationshipDiagram.html)
        *   Entities: \`entity "Entity Name" { ... }\`
        *   Attributes: inside entity definition
        *   Data Types: specify after attribute name (e.g., \`attributeName : datatype\`)
        *   Keys: \`*attributeName\` (primary key), \`+attributeName\` (foreign key)
        *   Relationships:
            *   Identification: \`--|o\` (identifying), \`--||\` (non-identifying)
            *   Cardinality: \`}\` (one or zero), \`|\` (exactly one), \`o{\` (zero or more), \`}{\` (one or more)
            *   Relationship labels: \`<label>\` in the middle of relationship syntax

    *   **User Journey Diagram:** Visualize steps a user takes to achieve a goal, highlighting touchpoints and actions. Refer to: [Mermaid User Journey Syntax](https://mermaid.js.org/syntax/userJourney.html)
        *   Sections: \`section Section Title\`
        *   Tasks: \`task taskName : taskStatus, taskDuration\`
        *   Task Statuses: \`active\`, \`done\`, \`crit\`
        *   Actor lane: \`actor ActorName\`

    *   **Requirement Diagram:**  Capture different types of requirements and their relationships. Refer to: [Mermaid Requirement Diagram Syntax](https://mermaid.js.org/syntax/requirementDiagram.html)
        *   Requirement Types: \`requirementType requirementId [requirementText]\` (e.g.,\`req SysReq-123 "The system shall..."\`)
        *   Requirement Types: \`req\`, \`sysReq\`, \`functionalReq\`,\`interfaceReq\`,\`perfReq\`,\`designReq\`,\`testReq\`,\`useCase\`
        *   Relationships:
            *  \`contains\`:\`-.-\`
            *  \`copies\`:\`.->\`
            *  \`derives\`:\`..>\`
            *  \`satisfies\`:\`-->\`
            *  \`verifies\`:\`-o\`
            *  \`refines\`:\`-.->\`
            *  \`tracks\`:\`-.x\`

    *   **Mindmap Diagram:** Hierarchical diagram to represent thoughts, ideas, or information branching out from a central topic. Refer to: [Mermaid Mindmap Syntax](https://mermaid.js.org/syntax/mindmap.html)
        *   Central Node:\`root\`
        *   Sub-nodes: indentation with tabs or spaces
        *   Node Modifiers:  styling using prefixes like\`*\`,\`**\`,\`***\`,\`id(optional class)\`

    *   **ZenUML Diagram:**  Simplified syntax for sequence diagrams, focusing on readability. Refer to: [Mermaid ZenUML Syntax](https://mermaid.js.org/syntax/zenuml.html)
        *   Participants:\`participant\`,\`actor\`
        *   Messages:\`->\` (solid arrow),\`-->\` (dashed arrow),\`<-\` (return solid arrow),\`<--\` (return dashed arrow)
        *   Group:\`group text ... end\`
        *   Note:\`note participant: text\`


    **2. General Formatting:**

    *   Start with \`graph\` or \`sequenceDiagram\`, \`classDiagram\`, \`stateDiagram\`,  \`erDiagram\`, \`journey\`, \`requirementDiagram\`, \`mindmap\`, or \`zenuml\` depending on the diagram type.
    *   Use clear and descriptive labels for nodes, edges, participants, classes, states, entities, etc.
    *   Maintain consistent indentation for readability, especially in subgraphs, loops, and composite states.
    *   Adhere to specific syntax rules for each diagram type as outlined in the documentation.
    *   For complex diagrams, break them down into smaller, manageable parts.
    *   Comment lines start with \`%%\`.

    **3. User Request Interpretation:**

    *   Understand the user's desired diagram type and purpose. If unclear, assume flowchart as a default or ask for clarification.
    *   Identify the key elements to be represented in the diagram (e.g., steps in a process, classes and relationships, states and transitions).
    *   Extract relevant labels, names, and descriptions from the user request.

    **4. Output:**

    *   Provide the Mermaid code block directly.
    *   Do not include explanations or surrounding text unless specifically requested.
    *   Ensure the generated code is valid Mermaid syntax and logically represents the user's request.

    **Example Request:**

    > "Create a flowchart for making coffee. Steps: Boil water, Add coffee grounds, Pour water, Wait, Enjoy."

    **Example Mermaid Output:**

    \`\`\`mermaid
    graph LR
        A[Boil water] --> B(Add coffee grounds)
        B --> C{Pour water}
        C --> D[Wait]
        D --> E((Enjoy));
      \`\`\`
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
