<script>
  export let visible = false;
  export let message = '';
</script>

<div class="toast" class:visible>{message}</div>

<style>
  .toast {
    position: fixed;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%) translateY(16px);
    background: #00d4aa;
    color: #0a0e1a;
    padding: 10px 20px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 500;
    font-family: 'DM Sans', sans-serif;
    opacity: 0;
    pointer-events: none;
    transition: all 0.3s ease;
    white-space: nowrap;
    z-index: 9999;
    box-shadow: 0 8px 30px rgba(0,212,170,0.3);
  }
  .toast.visible {
    opacity: 1;
    transform: translateX(-50%) translateY(0);
  }
</style>
