<script lang="ts">
    import { onMount, tick } from 'svelte';
    import { supabase } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import type { Order } from '$lib/types/orders';
    import { getTopBuyingUsers, getUsersWithMostDebt } from '$lib/services/orderService';
    import { fade } from 'svelte/transition';
    import Chart from 'chart.js/auto';
    import type { Chart as ChartType, ChartData, ChartOptions } from 'chart.js';
    import 'chartjs-adapter-date-fns';
      import { createNeonGradient, neonShadowPlugin } from '$lib/utils/chartNeon';
  import StarryBackground from '$lib/components/StarryBackground.svelte';
  import { starryBackground } from '$lib/stores/settingsStore';

  let user: any = null;
  let isAdmin = false;
  let isPosUser = false;

    let stats = {
      totalOrders: 0,
      totalRevenue: 0,
      cashToCollect: 0,
      cashCollected: 0
    };
    
    let cashIn = { today: 0, week: 0, month: 0, year: 0, all: 0 };
    let debtIn = 0;
    let debtCreated = { today: 0, week: 0, month: 0, year: 0, all: 0 };
  
    let topBuyers: { user_id: string; name?: string; email?: string; total: number }[] = [];
    let mostDebtUsers: { user_id: string; name?: string; email?: string; balance: number }[] = [];
    let topProducts: { name: string; quantity: number; }[] = [];
    
    let allOrders: (Pick<Order, 'id' | 'created_at' | 'total' | 'status' | 'deleted_at'>)[] = [];
  
    let revenueChartInstance: ChartType | null = null;
    let revenueFilter = 'year';
  
    let debtCreatedChartInstance: ChartType | null = null;
    let debtCreatedFilter: 'today' | 'week' | 'month' | 'year' = 'year';

    let cashCollectedChartInstance: ChartType | null = null;
    let cashCollectedPeriod: 'day' | 'week' | 'month' = 'day';
    let cashCollectedStartDate = new Date();
    let cashCollectedEndDate = new Date();

    let cashPaidChartInstance: ChartType | null = null;
    let creditChartInstance: ChartType | null = null;
    let debtChartInstance: ChartType | null = null;
    let totalSpentChartInstance: ChartType | null = null;

    let cashPaidPeriod: 'day' | 'week' | 'month' = 'day';
    let cashPaidStartDate = new Date(new Date().setDate(new Date().getDate() - 30));
    let cashPaidEndDate = new Date();

    let creditPeriod: 'day' | 'week' | 'month' = 'day';
    let creditStartDate = new Date(new Date().setDate(new Date().getDate() - 30));
    let creditEndDate = new Date();

    let debtPeriod: 'day' | 'week' | 'month' = 'day';
    let debtStartDate = new Date(new Date().setDate(new Date().getDate() - 30));
    let debtEndDate = new Date();

    let totalSpentStartDate = new Date(new Date().setDate(new Date().getDate() - 30));
    let totalSpentEndDate = new Date();
    let totalSpentLimit = 10;

    // Set default range to last 30 days
    cashCollectedStartDate.setDate(cashCollectedStartDate.getDate() - 30);

    Chart.register(neonShadowPlugin);

    onMount(async () => {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      user = authUser;
      if (!user) return goto('/');

      const { data: profile } = await supabase
        .from('profiles')
        .select('is_admin, role')
        .eq('auth_user_id', user.id)
        .maybeSingle();
      
      isAdmin = !!profile?.is_admin;
      isPosUser = profile?.role === 'pos';
      if (!isAdmin && !isPosUser) return goto('/');

      await fetchStats();
      await Promise.all([
        fetchTopBuyersAndDebtors(),
        fetchAndRenderRevenueChart(),
        fetchAndRenderDebtCreatedChart(),
        fetchAndRenderCashCollectedChart(),
        fetchAndRenderCashPaidChart(),
        fetchAndRenderCreditChart(),
        fetchAndRenderDebtChart(),
        fetchAndRenderTotalSpentChart()
      ]);
      
      await tick();
    });
  
    async function fetchStats() {
      try {
        const dashboardResult = await supabase.rpc('get_dashboard_stats');
        if (dashboardResult.error) throw dashboardResult.error;
        
        const data = dashboardResult.data;
        stats.totalOrders = data?.totalOrders || 0;
        stats.totalRevenue = data?.totalRevenue || 0;
        stats.cashToCollect = data?.cashToCollect || 0;
        stats.cashCollected = data?.cashCollectedToday || 0;
        topProducts = data?.topProducts || [];
        
        // Set debt created data from dashboard stats - only today is available from this function
        debtCreated.today = data?.debtCreatedToday || 0;
        
        // Get debt created for week and month from the new debt stats function
        const debtStatsResult = await supabase.rpc('get_debt_created_stats');
        if (debtStatsResult.error) throw debtStatsResult.error;
        
        const debtStats = debtStatsResult.data;
        if (debtStats) {
          debtCreated.week = debtStats.week || 0;
          debtCreated.month = debtStats.month || 0;
        } else {
          debtCreated.week = 0;
          debtCreated.month = 0;
        }

        const cashResult = await supabase.rpc('get_cash_in_stats');
        if (cashResult.error) throw cashResult.error;
        
        const cashStats = cashResult.data;
        if (cashStats) {
          cashIn = { 
            today: cashStats.today || 0, 
            week: cashStats.week || 0, 
            month: cashStats.month || 0, 
            year: cashStats.year || 0, 
            all: cashStats.all_time || 0 
          };
        }
      } catch (err: any) {
        console.error('Error fetching stats:', err);
      }
    }

    async function fetchTopBuyersAndDebtors() {
      const buyers = await getTopBuyingUsers(10);
      const debtors = await getUsersWithMostDebt(10);
      topBuyers = buyers.map((u: any) => ({ ...u, total: Number(u.total) }));
      mostDebtUsers = debtors.map((u: any) => ({ ...u, balance: Number(u.balance) })).filter((u: any) => u.balance < 0);
    }

    async function fetchAndRenderRevenueChart() {
        if (revenueChartInstance) revenueChartInstance.destroy();
        
        const ctx = document.getElementById('revenueChart') as HTMLCanvasElement;
        if (!ctx) return;
        const ctx2d = ctx.getContext('2d');
        if (!ctx2d) return;

        const { data: chartRpcData, error } = await supabase.rpc('get_revenue_chart_data', { filter_option: revenueFilter });
        if (error || !chartRpcData) {
          console.error('Error fetching revenue data:', error);
          return;
        }
        
        const chartType = revenueFilter === 'today' ? 'line' : 'bar';
        let labels, data;

        if (chartType === 'line') {
            labels = chartRpcData.map((d: any) => new Date(d.period).getTime());
            data = chartRpcData.map((d: any) => ({ x: new Date(d.period).getTime(), y: d.revenue }));
        } else {
            labels = chartRpcData.map((d: any) => d.period);
            data = chartRpcData.map((d: any) => d.revenue);
        }

        const gradient = createNeonGradient(ctx2d, '#00f2fe', '#4facfe');

        const chartData: ChartData = {
            labels: labels,
            datasets: [{
                label: 'Revenue',
                data: data,
                backgroundColor: gradient,
                borderColor: '#00f2fe',
                borderWidth: 3,
                pointBackgroundColor: '#fff',
                pointBorderColor: '#00f2fe',
                pointRadius: 6,
                fill: true,
                tension: 0.4
            }]
        };

        const chartOptions: ChartOptions = {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: 'rgba(30,30,60,0.95)',
                    titleColor: '#00f2fe',
                    bodyColor: '#fff',
                    borderColor: '#00f2fe',
                    borderWidth: 2,
                    padding: 12,
                    cornerRadius: 8
                }
            },
            scales: {
                x: revenueFilter === 'today' ? {
                    type: 'time',
                    time: { unit: 'hour', tooltipFormat: 'HH:mm', displayFormats: { hour: 'HH:mm' }},
                    grid: { display: false },
                    ticks: { color: '#b2fefa', font: { weight: 'bold' } }
                } : {
                    grid: { display: false },
                    ticks: { color: '#b2fefa', font: { weight: 'bold' } }
                },
                y: { 
                    beginAtZero: true,
                    grid: { color: 'rgba(0,242,254,0.1)' },
                    ticks: { color: '#b2fefa', font: { weight: 'bold' } }
                }
            }
        };

        revenueChartInstance = new Chart(ctx, { type: chartType, data: chartData, options: chartOptions, plugins: [neonShadowPlugin] });
    }

    function setRevenueFilter(filter: string) { 
      revenueFilter = filter; 
      fetchAndRenderRevenueChart(); 
    }

    async function fetchAndRenderDebtCreatedChart() {
        if (debtCreatedChartInstance) debtCreatedChartInstance.destroy();
        
        const ctx = document.getElementById('debtCreatedChart') as HTMLCanvasElement;
        if (!ctx) return;
        const ctx2d = ctx.getContext('2d');
        if (!ctx2d) return;

        try {
            const { data, error } = await supabase.rpc('get_debt_created_vs_paid', { filter_option: debtCreatedFilter });
            if (error) throw error;
            
            const chartType = debtCreatedFilter === 'today' ? 'line' : 'bar';
            let debtCreatedData, debtPaidData, labels;

            if (chartType === 'line') {
                labels = data.map((d: any) => new Date(d.period).getTime());
                debtCreatedData = data.map((d: any) => ({ x: new Date(d.period).getTime(), y: d.debt_created }));
                debtPaidData = data.map((d: any) => ({ x: new Date(d.period).getTime(), y: d.debt_paid }));
            } else {
                labels = data.map((d: any) => d.period);
                debtCreatedData = data.map((d: any) => d.debt_created);
                debtPaidData = data.map((d: any) => d.debt_paid);
            }

            const debtCreatedGradient = createNeonGradient(ctx2d, '#ff6a00', '#ee0979');
            const debtPaidGradient = createNeonGradient(ctx2d, '#43e97b', '#38f9d7');

            debtCreatedChartInstance = new Chart(ctx, {
                type: chartType,
                data: {
                    labels: labels,
                    datasets: [
                        {
                            label: 'Debt Created',
                            data: debtCreatedData,
                            backgroundColor: debtCreatedGradient,
                            borderColor: '#ff6a00',
                            borderWidth: 3,
                            pointBackgroundColor: '#fff',
                            pointBorderColor: '#ff6a00',
                            pointRadius: 6,
                            fill: true,
                            tension: 0.4,
                        },
                        {
                            label: 'Debt Paid',
                            data: debtPaidData,
                            backgroundColor: debtPaidGradient,
                            borderColor: '#43e97b',
                            borderWidth: 3,
                            pointBackgroundColor: '#fff',
                            pointBorderColor: '#43e97b',
                            pointRadius: 6,
                            fill: true,
                            tension: 0.4,
                        }
                    ]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { 
                            position: 'top',
                            labels: {
                                color: '#fff',
                                font: { weight: 'bold' }
                            }
                        },
                        tooltip: {
                            backgroundColor: 'rgba(30,30,60,0.95)',
                            titleColor: '#ff6a00',
                            bodyColor: '#fff',
                            borderColor: '#ff6a00',
                            borderWidth: 2,
                            padding: 12,
                            cornerRadius: 8,
                            mode: 'index',
                            intersect: false,
                        }
                    },
                    scales: {
                        x: chartType === 'line' ? {
                            type: 'time',
                            time: { unit: 'hour', tooltipFormat: 'HH:mm', displayFormats: { hour: 'HH:mm' } },
                            grid: { display: false },
                            ticks: { color: '#fff', font: { weight: 'bold' } }
                        } : {
                            stacked: true,
                            grid: { display: false },
                            ticks: { color: '#fff', font: { weight: 'bold' } }
                        },
                        y: { 
                            stacked: chartType === 'bar',
                            beginAtZero: true,
                            grid: { color: 'rgba(255,106,0,0.1)' },
                            ticks: { color: '#fff', font: { weight: 'bold' } }
                        }
                    }
                },
                plugins: [neonShadowPlugin]
            });
        } catch (err) {
            console.error('Error fetching debt data:', err);
        }
    }

    function setDebtCreatedFilter(filter: 'today' | 'week' | 'month' | 'year') {
        debtCreatedFilter = filter;
        fetchAndRenderDebtCreatedChart();
    }

    async function fetchAndRenderCashCollectedChart() {
        if (cashCollectedChartInstance) cashCollectedChartInstance.destroy();
        const ctx = document.getElementById('cashCollectedChart') as HTMLCanvasElement;
        if (!ctx) return;
        const ctx2d = ctx.getContext('2d');
        if (!ctx2d) return;
        const { data, error } = await supabase.rpc('get_cash_collected_chart_data', {
            p_period: cashCollectedPeriod,
            p_start_date: cashCollectedStartDate.toISOString(),
            p_end_date: cashCollectedEndDate.toISOString()
        });
        if (error || !data) {
            console.error('Error fetching cash collected chart data:', error);
            return;
        }
        const labels = data.map((row: any) => new Date(row.period_start).toLocaleDateString());
        const values = data.map((row: any) => Number(row.cash_collected));
        const gradient = createNeonGradient(ctx2d, '#43e97b', '#38f9d7');
        cashCollectedChartInstance = new Chart(ctx, {
            type: 'line',
            data: {
                labels,
                datasets: [{
                    label: 'Cash Collected',
                    data: values,
                    borderColor: '#43e97b',
                    backgroundColor: gradient,
                    borderWidth: 3,
                    pointBackgroundColor: '#fff',
                    pointBorderColor: '#43e97b',
                    pointRadius: 6,
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: 'rgba(30,30,60,0.95)',
                        titleColor: '#43e97b',
                        bodyColor: '#fff',
                        borderColor: '#43e97b',
                        borderWidth: 2,
                        padding: 12,
                        cornerRadius: 8
                    }
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: { color: '#b2fefa', font: { weight: 'bold' } }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: 'rgba(67,233,123,0.1)' },
                        ticks: { color: '#b2fefa', font: { weight: 'bold' } }
                    }
                }
            },
            plugins: [neonShadowPlugin]
        });
    }

    function onCashCollectedFilterChange() {
        fetchAndRenderCashCollectedChart();
    }

    let cashPaidLoading = false;
    let cashPaidError = '';
    let cashPaidData: any[] = [];
    async function fetchAndRenderCashPaidChart() {
      cashPaidLoading = true;
      cashPaidError = '';
      if (cashPaidChartInstance) cashPaidChartInstance.destroy();
      const ctx = document.getElementById('cashPaidChart') as HTMLCanvasElement;
      if (!ctx) { cashPaidLoading = false; return; }
      const ctx2d = ctx.getContext('2d');
      if (!ctx2d) { cashPaidLoading = false; return; }
      try {
        const { data, error } = await supabase.rpc('get_cash_paid_over_time', {
          p_period: cashPaidPeriod,
          p_start_date: new Date(cashPaidStartDate).toISOString(),
          p_end_date: new Date(cashPaidEndDate).toISOString()
        });
        if (error) throw error;
        cashPaidData = data;
        const labels = data.map((row: any) => new Date(row.period).toLocaleDateString());
        const values = data.map((row: any) => Number(row.cash_paid));
        const gradient = createNeonGradient(ctx2d, '#43e97b', '#38f9d7');
        cashPaidChartInstance = new Chart(ctx, {
          type: 'line',
          data: { labels, datasets: [{ label: 'Cash Paid', data: values, borderColor: '#43e97b', backgroundColor: gradient, borderWidth: 3, pointBackgroundColor: '#fff', pointBorderColor: '#43e97b', pointRadius: 6, fill: true, tension: 0.4 }] },
          options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { backgroundColor: 'rgba(30,30,60,0.95)', titleColor: '#43e97b', bodyColor: '#fff', borderColor: '#43e97b', borderWidth: 2, padding: 12, cornerRadius: 8 } }, scales: { x: { grid: { display: false }, ticks: { color: '#b2fefa', font: { weight: 'bold' } } }, y: { beginAtZero: true, grid: { color: 'rgba(67,233,123,0.1)' }, ticks: { color: '#b2fefa', font: { weight: 'bold' } } } } }, plugins: [neonShadowPlugin] });
      } catch (err: any) {
        cashPaidError = err.message || 'Failed to load chart data.';
      } finally {
        cashPaidLoading = false;
      }
    }
    const debouncedFetchAndRenderCashPaidChart = debounce(fetchAndRenderCashPaidChart, 300);

    async function fetchAndRenderCreditChart() {
        if (creditChartInstance) creditChartInstance.destroy();
        const ctx = document.getElementById('creditChart') as HTMLCanvasElement;
        if (!ctx) return;
        const ctx2d = ctx.getContext('2d');
        if (!ctx2d) return;
        const { data, error } = await supabase.rpc('get_credit_over_time', {
            p_period: creditPeriod,
            p_start_date: creditStartDate.toISOString(),
            p_end_date: creditEndDate.toISOString()
        });
        if (error || !data) { console.error('Error fetching credit data:', error); return; }
        const labels = data.map((row: any) => new Date(row.period).toLocaleDateString());
        const values = data.map((row: any) => Number(row.credit));
        const gradient = createNeonGradient(ctx2d, '#00f2fe', '#4facfe');
        creditChartInstance = new Chart(ctx, {
            type: 'line',
            data: { labels, datasets: [{ label: 'Credit', data: values, borderColor: '#00f2fe', backgroundColor: gradient, borderWidth: 3, pointBackgroundColor: '#fff', pointBorderColor: '#00f2fe', pointRadius: 6, fill: true, tension: 0.4 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { backgroundColor: 'rgba(30,30,60,0.95)', titleColor: '#00f2fe', bodyColor: '#fff', borderColor: '#00f2fe', borderWidth: 2, padding: 12, cornerRadius: 8 } }, scales: { x: { grid: { display: false }, ticks: { color: '#b2fefa', font: { weight: 'bold' } } }, y: { beginAtZero: true, grid: { color: 'rgba(0,242,254,0.1)' }, ticks: { color: '#b2fefa', font: { weight: 'bold' } } } } }, plugins: [neonShadowPlugin] });
    }

    async function fetchAndRenderDebtChart() {
        if (debtChartInstance) debtChartInstance.destroy();
        const ctx = document.getElementById('debtChart') as HTMLCanvasElement;
        if (!ctx) return;
        const ctx2d = ctx.getContext('2d');
        if (!ctx2d) return;
        const { data, error } = await supabase.rpc('get_debt_over_time', {
            p_period: debtPeriod,
            p_start_date: debtStartDate.toISOString(),
            p_end_date: debtEndDate.toISOString()
        });
        if (error || !data) { console.error('Error fetching debt data:', error); return; }
        const labels = data.map((row: any) => new Date(row.period).toLocaleDateString());
        const values = data.map((row: any) => Number(row.debt));
        const gradient = createNeonGradient(ctx2d, '#ff6a00', '#ee0979');
        debtChartInstance = new Chart(ctx, {
            type: 'line',
            data: { labels, datasets: [{ label: 'Debt', data: values, borderColor: '#ff6a00', backgroundColor: gradient, borderWidth: 3, pointBackgroundColor: '#fff', pointBorderColor: '#ff6a00', pointRadius: 6, fill: true, tension: 0.4 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { backgroundColor: 'rgba(30,30,60,0.95)', titleColor: '#ff6a00', bodyColor: '#fff', borderColor: '#ff6a00', borderWidth: 2, padding: 12, cornerRadius: 8 } }, scales: { x: { grid: { display: false }, ticks: { color: '#b2fefa', font: { weight: 'bold' } } }, y: { beginAtZero: true, grid: { color: 'rgba(255,106,0,0.1)' }, ticks: { color: '#b2fefa', font: { weight: 'bold' } } } } }, plugins: [neonShadowPlugin] });
    }

    async function fetchAndRenderTotalSpentChart() {
        if (totalSpentChartInstance) totalSpentChartInstance.destroy();
        const ctx = document.getElementById('totalSpentChart') as HTMLCanvasElement;
        if (!ctx) return;
        const ctx2d = ctx.getContext('2d');
        if (!ctx2d) return;
        const { data, error } = await supabase.rpc('get_total_spent_top_users', {
            p_start_date: totalSpentStartDate.toISOString(),
            p_end_date: totalSpentEndDate.toISOString(),
            p_limit: totalSpentLimit
        });
        if (error || !data) { console.error('Error fetching total spent data:', error); return; }
        const labels = data.map((row: any) => row.user_name || row.user_id);
        const values = data.map((row: any) => Number(row.total_spent));
        const gradient = createNeonGradient(ctx2d, '#b993d6', '#8ca6db');
        totalSpentChartInstance = new Chart(ctx, {
            type: 'bar',
            data: { labels, datasets: [{ label: 'Total Spent', data: values, backgroundColor: gradient, borderColor: '#b993d6', borderWidth: 3 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { backgroundColor: 'rgba(30,30,60,0.95)', titleColor: '#b993d6', bodyColor: '#fff', borderColor: '#b993d6', borderWidth: 2, padding: 12, cornerRadius: 8 } }, scales: { x: { grid: { display: false }, ticks: { color: '#b2fefa', font: { weight: 'bold' } } }, y: { beginAtZero: true, grid: { color: 'rgba(185,147,214,0.1)' }, ticks: { color: '#b2fefa', font: { weight: 'bold' } } } } }, plugins: [neonShadowPlugin] });
    }

    // Fetch on mount and whenever filters change
    onMount(() => {
        fetchAndRenderCashPaidChart();
        fetchAndRenderCreditChart();
        fetchAndRenderDebtChart();
        fetchAndRenderTotalSpentChart();
    });

    // Update on change
    $: cashPaidPeriod, cashPaidStartDate, cashPaidEndDate, fetchAndRenderCashPaidChart();
    $: creditPeriod, creditStartDate, creditEndDate, fetchAndRenderCreditChart();
    $: debtPeriod, debtStartDate, debtEndDate, fetchAndRenderDebtChart();
    $: totalSpentStartDate, totalSpentEndDate, totalSpentLimit, fetchAndRenderTotalSpentChart();

    // Utility: debounce
    function debounce<T extends (...args: any[]) => void>(fn: T, delay: number): T {
      let timeout: ReturnType<typeof setTimeout>;
      return ((...args: any[]) => {
        clearTimeout(timeout);
        timeout = setTimeout(() => fn(...args), delay);
      }) as T;
    }



    // Utility: export to CSV
    function exportToCSV(filename: string, rows: any[], headers: string[]) {
      const csv = [headers.join(',')].concat(rows.map(row => headers.map(h => JSON.stringify(row[h] ?? '')).join(','))).join('\r\n');
      const blob = new Blob([csv], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }

</script>

<div class="admin-main">
  <div class="admin-container">
    <h1 class="neon-text-cyan">Admin Dashboard</h1>
    <div class="starry-toggle-row">
      <button class="btn btn-primary" on:click={fetchStats}>🔄 Refresh Stats</button>
      <label class="starry-toggle">
        <input type="checkbox" bind:checked={$starryBackground} />
        <span class="slider"></span>
        <span class="label-text">Starry Background</span>
      </label>
    </div>
    <StarryBackground />

    {#if isAdmin}
      <section id="stats" class="mb-4">
        <div class="card">
          <div class="card-header">
            <h2 class="neon-text-cyan">Sales Statistics</h2>
          </div>
          <div class="card-body">
            <div class="grid grid-3 gap-3">
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Total Orders</h3>
                <p class="neon-text-cyan text-2xl font-bold">{stats.totalOrders ?? 0}</p>
              </div>
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Total Revenue</h3>
                <p class="neon-text-cyan text-2xl font-bold">R{(stats.totalRevenue ?? 0).toFixed(2)}</p>
              </div>
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Cash to Collect</h3>
                <p class="neon-text-cyan text-2xl font-bold">R{(stats.cashToCollect ?? 0).toFixed(2)}</p>
              </div>
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Cash Collected Today</h3>
                <p class="neon-text-cyan text-2xl font-bold">R{(stats.cashCollected ?? 0).toFixed(2)}</p>
              </div>
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Cash In</h3>
                <ul class="text-sm">
                  <li>Today: <strong class="neon-text-cyan">R{(cashIn.today ?? 0).toFixed(2)}</strong></li>
                  <li>This Week: <strong class="neon-text-cyan">R{(cashIn.week ?? 0).toFixed(2)}</strong></li>
                  <li>This Month: <strong class="neon-text-cyan">R{(cashIn.month ?? 0).toFixed(2)}</strong></li>
                </ul>
              </div>
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Debt Created</h3>
                <ul class="text-sm">
                  <li>Today: <strong class="neon-text-cyan">R{(debtCreated.today ?? 0).toFixed(2)}</strong></li>
                  <li>This Week: <strong class="neon-text-cyan">R{(debtCreated.week ?? 0).toFixed(2)}</strong></li>
                  <li>This Month: <strong class="neon-text-cyan">R{(debtCreated.month ?? 0).toFixed(2)}</strong></li>
                </ul>
              </div>
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Top Buyers</h3>
                <ul class="user-list text-sm">
                  {#each topBuyers.slice(0, 5) as user}
                    <li>
                      <span>{user.name || user.email}</span>
                      <span class="neon-text-cyan">R{(user.total ?? 0).toFixed(2)}</span>
                    </li>
                  {/each}
                </ul>
              </div>
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Most Debt</h3>
                <ul class="user-list text-sm">
                  {#each mostDebtUsers.slice(0, 5) as user}
                    <li>
                      <span>{user.name || user.email}</span>
                      <span class="text-red-400">R{(Math.abs(user.balance) ?? 0).toFixed(2)}</span>
                    </li>
                  {/each}
                </ul>
              </div>
              <div class="glass-light p-3 text-center hover-glow">
                <h3 class="neon-text-white">Most Selling Products</h3>
                <ul class="user-list text-sm">
                  {#each topProducts as product}
                    <li>
                      <span>{product.name}</span>
                      <span class="neon-text-cyan">{product.quantity}</span>
                    </li>
                  {/each}
                </ul>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="grid grid-3 gap-4 mb-4">
        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Revenue Over Time</h2>
          </div>
          <div class="card-body">
            <div class="filter-btns">
              <button class="btn btn-sm {revenueFilter==='today' ? 'btn-primary' : 'btn-secondary'}" on:click={() => setRevenueFilter('today')}>Today</button>
              <button class="btn btn-sm {revenueFilter==='week' ? 'btn-primary' : 'btn-secondary'}" on:click={() => setRevenueFilter('week')}>This Week</button>
              <button class="btn btn-sm {revenueFilter==='month' ? 'btn-primary' : 'btn-secondary'}" on:click={() => setRevenueFilter('month')}>This Month</button>
              <button class="btn btn-sm {revenueFilter==='year' ? 'btn-primary' : 'btn-secondary'}" on:click={() => setRevenueFilter('year')}>This Year</button>
            </div>
            <div class="chart-wrapper">
              <canvas id="revenueChart"></canvas>
            </div>
          </div>
        </div>

        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Debt Created vs. Paid</h2>
          </div>
          <div class="card-body">
            <div class="filter-btns">
              <button class="btn btn-sm {debtCreatedFilter==='today' ? 'btn-primary' : 'btn-secondary'}" on:click={() => setDebtCreatedFilter('today')}>Today</button>
              <button class="btn btn-sm {debtCreatedFilter==='week' ? 'btn-primary' : 'btn-secondary'}" on:click={() => setDebtCreatedFilter('week')}>This Week</button>
              <button class="btn btn-sm {debtCreatedFilter==='month' ? 'btn-primary' : 'btn-secondary'}" on:click={() => setDebtCreatedFilter('month')}>This Month</button>
              <button class="btn btn-sm {debtCreatedFilter==='year' ? 'btn-primary' : 'btn-secondary'}" on:click={() => setDebtCreatedFilter('year')}>This Year</button>
            </div>
            <div class="chart-wrapper">
              <canvas id="debtCreatedChart"></canvas>
            </div>
          </div>
        </div>

        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Cash Collected Over Time</h2>
          </div>
          <div class="card-body">
            <div class="filters">
              <label class="form-label">Period:
                <select bind:value={cashCollectedPeriod} on:change={onCashCollectedFilterChange} class="form-control form-select">
                  <option value="day">Day</option>
                  <option value="week">Week</option>
                  <option value="month">Month</option>
                </select>
              </label>
              <label class="form-label">Start Date:
                <input type="date" bind:value={cashCollectedStartDate} on:change={onCashCollectedFilterChange} class="form-control" />
              </label>
              <label class="form-label">End Date:
                <input type="date" bind:value={cashCollectedEndDate} on:change={onCashCollectedFilterChange} class="form-control" />
              </label>
            </div>
            <div class="chart-wrapper">
              <canvas id="cashCollectedChart"></canvas>
            </div>
          </div>
        </div>
      </section>

      <section class="grid grid-2 gap-4">
        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Cash Paid Over Time</h2>
          </div>
          <div class="card-body">
            <div class="filters">
              <label class="form-label">Period:
                <select id="cashPaidPeriod" bind:value={cashPaidPeriod} on:change={debouncedFetchAndRenderCashPaidChart} class="form-control form-select">
                  <option value="day">Day</option>
                  <option value="week">Week</option>
                  <option value="month">Month</option>
                </select>
              </label>
              <label class="form-label">Start Date:
                <input id="cashPaidStartDate" type="date" bind:value={cashPaidStartDate} on:change={debouncedFetchAndRenderCashPaidChart} class="form-control" />
              </label>
              <label class="form-label">End Date:
                <input id="cashPaidEndDate" type="date" bind:value={cashPaidEndDate} on:change={debouncedFetchAndRenderCashPaidChart} class="form-control" />
              </label>
              <button type="button" class="btn btn-secondary" on:click={() => exportToCSV('cash_paid.csv', cashPaidData, ['period','cash_paid'])}>Export CSV</button>
            </div>
            {#if cashPaidLoading}
              <div class="text-center"><div class="spinner-large"></div></div>
            {:else if cashPaidError}
              <div class="alert alert-danger">{cashPaidError}</div>
            {:else}
              <canvas id="cashPaidChart" width="600" height="300"></canvas>
            {/if}
          </div>
        </div>

        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Credit Over Time</h2>
          </div>
          <div class="card-body">
            <div class="filters">
              <label class="form-label">Period:
                <select bind:value={creditPeriod} class="form-control form-select">
                  <option value="day">Day</option>
                  <option value="week">Week</option>
                  <option value="month">Month</option>
                </select>
              </label>
              <label class="form-label">Start Date:
                <input type="date" bind:value={creditStartDate} class="form-control" />
              </label>
              <label class="form-label">End Date:
                <input type="date" bind:value={creditEndDate} class="form-control" />
              </label>
            </div>
            <div class="chart-wrapper">
              <canvas id="creditChart"></canvas>
            </div>
          </div>
        </div>

        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Debt Over Time</h2>
          </div>
          <div class="card-body">
            <div class="filters">
              <label class="form-label">Period:
                <select bind:value={debtPeriod} class="form-control form-select">
                  <option value="day">Day</option>
                  <option value="week">Week</option>
                  <option value="month">Month</option>
                </select>
              </label>
              <label class="form-label">Start Date:
                <input type="date" bind:value={debtStartDate} class="form-control" />
              </label>
              <label class="form-label">End Date:
                <input type="date" bind:value={debtEndDate} class="form-control" />
              </label>
            </div>
            <div class="chart-wrapper">
              <canvas id="debtChart"></canvas>
            </div>
          </div>
        </div>

        <div class="glass">
          <div class="card-header">
            <h2 class="neon-text-cyan">Top Total Spent Users</h2>
          </div>
          <div class="card-body">
            <div class="filters">
              <label class="form-label">Start Date:
                <input type="date" bind:value={totalSpentStartDate} class="form-control" />
              </label>
              <label class="form-label">End Date:
                <input type="date" bind:value={totalSpentEndDate} class="form-control" />
              </label>
              <label class="form-label">Limit:
                <input type="number" min="1" max="50" bind:value={totalSpentLimit} class="form-control" />
              </label>
            </div>
            <div class="chart-wrapper">
              <canvas id="totalSpentChart"></canvas>
            </div>
          </div>
        </div>
      </section>
    {/if}
  </div>
</div>

<style>
  .admin-main {
    min-height: 100vh;
    padding-top: 80px;
    background: transparent;
  }

  .admin-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
  }

  .starry-toggle-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 1.5rem;
  }

  .starry-toggle {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 1.1rem;
    color: var(--text-secondary);
    background: var(--bg-glass);
    border-radius: 20px;
    padding: 0.5rem 1.2rem;
    box-shadow: var(--shadow-glass);
  }

  .starry-toggle input[type="checkbox"] {
    width: 0;
    height: 0;
    opacity: 0;
    position: absolute;
  }

  .starry-toggle .slider {
    width: 40px;
    height: 22px;
    background: #222b3a;
    border-radius: 22px;
    position: relative;
    transition: background 0.3s;
    box-shadow: 0 0 8px #00f2fe44;
  }

  .starry-toggle input[type="checkbox"]:checked + .slider {
    background: var(--gradient-primary);
    box-shadow: 0 0 16px #00f2fe99;
  }

  .starry-toggle .slider:before {
    content: '';
    position: absolute;
    left: 3px;
    top: 3px;
    width: 16px;
    height: 16px;
    background: #fff;
    border-radius: 50%;
    transition: transform 0.3s;
    box-shadow: 0 2px 6px #00f2fe44;
  }

  .starry-toggle input[type="checkbox"]:checked + .slider:before {
    transform: translateX(18px);
    background: var(--neon-cyan);
  }

  .label-text {
    margin-left: 0.5rem;
    font-weight: 500;
    color: var(--text-secondary);
    letter-spacing: 0.02em;
  }

  .filter-btns {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
  }

  .filters {
    display: flex;
    gap: 1rem;
    margin-bottom: 1rem;
    align-items: end;
    flex-wrap: wrap;
  }

  .filters label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .chart-wrapper {
    position: relative;
    height: 300px;
    width: 100%;
  }

  .user-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .user-list li {
    display: flex;
    justify-content: space-between;
    padding: 0.25rem 0;
    border-bottom: 1px solid var(--border-primary);
  }

  .user-list li:last-child {
    border-bottom: none;
  }

  .text-red-400 {
    color: #f87171;
  }

  .text-2xl {
    font-size: 1.5rem;
  }

  @media (max-width: 1200px) {
    .admin-container {
      padding: 1rem;
    }
    
    .grid-3 {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 768px) {
    .starry-toggle-row {
      flex-direction: column;
      gap: 1rem;
      align-items: stretch;
    }
    
    .grid-3,
    .grid-2 {
      grid-template-columns: 1fr;
    }
    
    .filters {
      flex-direction: column;
      align-items: stretch;
    }
    
    .filter-btns {
      flex-direction: column;
    }
  }
</style>