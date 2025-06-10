<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';
  import SignaturePad from 'signature_pad';


  export let lineWidth = 2;
  export let lineColor = '#000000';
  export let backgroundColor = '#ffffff';
  export let width = 200;
  export let height = 100;

  let canvas: HTMLCanvasElement;
  let signaturePad: SignaturePad;
  let isEmpty = true;
  const dispatch = createEventDispatcher();

  onMount(() => {
    signaturePad = new SignaturePad(canvas, {
      minWidth: lineWidth,
      maxWidth: lineWidth,
      penColor: lineColor,
      backgroundColor: backgroundColor,
    });

    // Event listeners for changes
    signaturePad.addEventListener("beginStroke", () => {
      isEmpty = false;
      dispatch('change', { isEmpty });
    });
    signaturePad.addEventListener("endStroke", () => {
      isEmpty = signaturePad.isEmpty();
      dispatch('change', { isEmpty });
    });

    function resizeCanvas() {
      const ratio = Math.max(window.devicePixelRatio || 1, 1);
      canvas.width = canvas.offsetWidth * ratio;
      canvas.height = canvas.offsetHeight * ratio;
      canvas.getContext('2d')!.scale(ratio, ratio);
      signaturePad.clear();
    }

    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();

    clear();

    return () => {
      window.removeEventListener('resize', resizeCanvas);
      signaturePad.off();
    };
  });

  export function clear() {
    signaturePad.clear();
    isEmpty = true;
    dispatch('change', { isEmpty });
  }

  export function getSignatureData(): string {
    if (signaturePad.isEmpty()) {
      return '';
    }
    return signaturePad.toDataURL('image/png');
  }
</script>

<div class="signature-pad">
  <canvas
    bind:this={canvas}
  ></canvas>
  <div class="controls">
    <button type="button" on:click={clear}>Clear</button>
  </div>
</div>

<style>
  .signature-pad {
    border: 1px solid #ccc;
    border-radius: 4px;
    overflow: hidden;
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  canvas {
    display: block;
    touch-action: none;
    flex-grow: 1;
    width: 100%;
    height: 100%;
  }

  .controls {
    padding: 0.5rem;
    background: #f8f9fa;
    border-top: 1px solid #ccc;
  }

  button {
    padding: 0.25rem 0.5rem;
    background: #dc3545;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }

  button:hover {
    background: #c82333;
  }
</style> 