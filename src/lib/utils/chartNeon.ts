// Neon/glassy chart utilities for Chart.js
export function createNeonGradient(ctx: CanvasRenderingContext2D, color1: string, color2: string) {
    const gradient = ctx.createLinearGradient(0, 0, 0, 400);
    gradient.addColorStop(0, color1);
    gradient.addColorStop(1, color2);
    return gradient;
}

// Optionally, you can add a Chart.js plugin for neon shadow effects
// Usage: Chart.register(neonShadowPlugin);
export const neonShadowPlugin = {
    id: 'neonShadow',
    beforeDatasetsDraw(chart: any) {
        const ctx = chart.ctx;
        ctx.save();
        ctx.shadowColor = 'rgba(0,242,254,0.7)';
        ctx.shadowBlur = 16;
    },
    afterDatasetsDraw(chart: any) {
        chart.ctx.restore();
    }
}; 