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
    
    let allOrders: Order[] = [];
  
    let revenueChartInstance: ChartType | null = null;
    let revenueFilter = 'year';
  
    let debtCreatedChartInstance: ChartType | null = null;
    let debtCreatedFilter: 'today' | 'week' | 'month' | 'year' = 'year';
  
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
        fetchAndRenderDebtCreatedChart()
      ]);
      
      await tick();
      renderRevenueChart();
    });
  
    async function fetchStats() {
      try {
        const { data: ordersData, error: ordersError } = await supabase
          .from('orders')
          .select(`*, order_items (quantity, products:product_id(name))`)
          .order('created_at', { ascending: false });

        if (ordersError) throw ordersError;
        allOrders = ordersData || [];

        const validOrders = allOrders.filter(order => !order.deleted_at && order.status === 'completed');
        stats.totalOrders = validOrders.length;
        stats.totalRevenue = validOrders.reduce((total, order) => total + (order.total || 0), 0);

        const productStats = new Map<string, number>();
        validOrders.forEach(order => {
          order.order_items?.forEach((item: any) => {
            if (!item.products) return;
            const name = item.products.name;
            productStats.set(name, (productStats.get(name) || 0) + item.quantity);
          });
        });
        topProducts = Array.from(productStats.entries())
          .map(([name, quantity]) => ({ name, quantity }))
          .sort((a, b) => b.quantity - a.quantity)
          .slice(0, 5);

        const pendingCashOrders = allOrders.filter(order => !order.deleted_at && order.status === 'pending' && order.payment_method === 'cash');
        stats.cashToCollect = pendingCashOrders.reduce((sum, order) => sum + (order.total || 0), 0);

        const { data: ledgerCashIn, error: cashInError } = await supabase.from('transactions').select('payment_amount, created_at').eq('method', 'cash');
        if (cashInError) throw cashInError;

        const now = new Date();
        const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const startOfWeek = new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay());
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const startOfYear = new Date(now.getFullYear(), 0, 1);

        cashIn = { today: 0, week: 0, month: 0, year: 0, all: 0 };
        for (const entry of ledgerCashIn) {
          const created = new Date(entry.created_at);
          if (created >= startOfToday) cashIn.today += entry.payment_amount;
          if (created >= startOfWeek) cashIn.week += entry.payment_amount;
          if (created >= startOfMonth) cashIn.month += entry.payment_amount;
          if (created >= startOfYear) cashIn.year += entry.payment_amount;
          cashIn.all += entry.payment_amount;
        }
        stats.cashCollected = cashIn.today;
      } catch (err) {
        console.error('Error fetching stats:', err);
      }
    }

    async function fetchTopBuyersAndDebtors() {
      const buyers = await getTopBuyingUsers(10);
      const debtors = await getUsersWithMostDebt(10);
      topBuyers = buyers.map(u => ({ ...u, total: Number(u.total) }));
      mostDebtUsers = debtors.map(u => ({ ...u, balance: Number(u.balance) })).filter(u => u.balance < 0);
    }

    function getRevenueDataByFilter(orders: Order[], filter: string) {
        const now = new Date();
        let startDate: Date;
        
        if (filter === 'today') {
            startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            const todayData = orders
                .filter(o => new Date(o.created_at) >= startDate && o.status === 'completed' && !o.deleted_at)
                .map(o => ({
                    x: new Date(o.created_at).getTime(),
                    y: o.total || 0
                }))
                .sort((a, b) => a.x - b.x);
            return { data: todayData, labels: [] };
        }

        let groupedData: { [key: string]: number } = {};
        let labels: string[] = [];
        
        switch (filter) {
            case 'week':
                startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay());
                ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].forEach(day => groupedData[day] = 0);
                break;
            case 'month':
                startDate = new Date(now.getFullYear(), now.getMonth(), 1);
                for (let i=1; i<=now.getDate(); i++) groupedData[i.toString()] = 0;
                break;
            case 'year':
            default:
                startDate = new Date(now.getFullYear(), 0, 1);
                ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'].forEach(m => groupedData[m]=0);
        }

        orders
            .filter(o => new Date(o.created_at) >= startDate && o.status === 'completed' && !o.deleted_at)
            .forEach(o => {
                const date = new Date(o.created_at);
                let key = '';
                if (filter === 'week') key = date.toLocaleDateString('en-US', { weekday: 'short' });
                else if (filter === 'month') key = date.getDate().toString();
                else if (filter === 'year') key = date.toLocaleDateString('en-US', { month: 'short' });
                if (key in groupedData) groupedData[key] += o.total || 0;
            });
        
        labels = Object.keys(groupedData);
        if(filter === 'month') labels.sort((a,b) => parseInt(a) - parseInt(b));
        if(filter === 'year') labels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        
        const data = labels.map(label => groupedData[label]);
        return { labels, data };
    }

    function renderRevenueChart() {
        if (revenueChartInstance) revenueChartInstance.destroy();
        
        const ctx = document.getElementById('revenueChart') as HTMLCanvasElement;
        if (!ctx) return;

        const { labels, data } = getRevenueDataByFilter(allOrders, revenueFilter);

        const chartType = revenueFilter === 'today' ? 'line' : 'bar';
        
        const gradient = ctx.getContext('2d')?.createLinearGradient(0, 0, 0, 400);
        gradient?.addColorStop(0, 'rgba(54, 162, 235, 0.5)');
        gradient?.addColorStop(1, 'rgba(54, 162, 235, 0)');

        const chartData: ChartData = {
            labels: labels,
            datasets: [{
                label: 'Revenue',
                data: data,
                backgroundColor: gradient,
                borderColor: 'rgba(54, 162, 235, 1)',
                borderWidth: 2,
                pointBackgroundColor: 'rgba(54, 162, 235, 1)',
                pointBorderColor: '#fff',
                pointHoverRadius: 6,
                pointHoverBorderWidth: 2,
                pointRadius: 4,
                fill: true,
                tension: 0.4
            }]
        };

        const chartOptions: ChartOptions = {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: revenueFilter === 'today' ? {
                    type: 'time',
                    time: { unit: 'hour', tooltipFormat: 'HH:mm', displayFormats: { hour: 'HH:mm' }},
                    grid: { display: false },
                    ticks: { color: '#666' }
                } : {
                    grid: { display: false },
                    ticks: { color: '#666' }
                },
                y: { 
                    beginAtZero: true,
                    grid: { color: '#e9ecef' },
                    ticks: { color: '#666' }
                }
            },
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: '#fff',
                    titleColor: '#333',
                    bodyColor: '#333',
                    borderColor: '#ddd',
                    borderWidth: 1,
                    padding: 10,
                    caretSize: 6,
                    cornerRadius: 6
                }
            }
        };

        revenueChartInstance = new Chart(ctx, { type: chartType, data: chartData, options: chartOptions });
    }

    function setRevenueFilter(filter: string) { revenueFilter = filter; renderRevenueChart(); }

    async function fetchAndRenderDebtCreatedChart() {
        if (debtCreatedChartInstance) debtCreatedChartInstance.destroy();
        
        const ctx = document.getElementById('debtCreatedChart') as HTMLCanvasElement;
        if (!ctx) return;

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

            const debtCreatedGradient = ctx.getContext('2d')?.createLinearGradient(0, 0, 0, 400);
            debtCreatedGradient?.addColorStop(0, 'rgba(255, 99, 132, 0.5)');
            debtCreatedGradient?.addColorStop(1, 'rgba(255, 99, 132, 0)');
            
            const debtPaidGradient = ctx.getContext('2d')?.createLinearGradient(0, 0, 0, 400);
            debtPaidGradient?.addColorStop(0, 'rgba(75, 192, 192, 0.5)');
            debtPaidGradient?.addColorStop(1, 'rgba(75, 192, 192, 0)');

            debtCreatedChartInstance = new Chart(ctx, {
                type: chartType,
                data: {
                    labels: labels,
                    datasets: [
                        {
                            label: 'Debt Created',
                            data: debtCreatedData,
                            backgroundColor: debtCreatedGradient,
                            borderColor: 'rgba(255, 99, 132, 1)',
                            borderWidth: 2,
                            pointBackgroundColor: 'rgba(255, 99, 132, 1)',
                            pointBorderColor: '#fff',
                            pointHoverRadius: 6,
                            pointHoverBorderWidth: 2,
                            pointRadius: 4,
                            fill: true,
                            tension: 0.4,
                        },
                        {
                            label: 'Debt Paid',
                            data: debtPaidData,
                            backgroundColor: debtPaidGradient,
                            borderColor: 'rgba(75, 192, 192, 1)',
                            borderWidth: 2,
                            pointBackgroundColor: 'rgba(75, 192, 192, 1)',
                            pointBorderColor: '#fff',
                            pointHoverRadius: 6,
                            pointHoverBorderWidth: 2,
                            pointRadius: 4,
                            fill: true,
                            tension: 0.4,
                        }
                    ]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        x: chartType === 'line' ? {
                            type: 'time',
                            time: { unit: 'hour', tooltipFormat: 'HH:mm', displayFormats: { hour: 'HH:mm' } },
                            grid: { display: false },
                            ticks: { color: '#666' }
                        } : {
                            stacked: true,
                            grid: { display: false },
                            ticks: { color: '#666' }
                        },
                        y: { 
                            stacked: chartType === 'bar',
                            beginAtZero: true,
                            grid: { color: '#e9ecef' },
                            ticks: { color: '#666' }
                        }
                    },
                    plugins: {
                        legend: { 
                            position: 'top',
                            labels: {
                                color: '#333'
                            }
                        },
                        tooltip: {
                            backgroundColor: '#fff',
                            titleColor: '#333',
                            bodyColor: '#333',
                            borderColor: '#ddd',
                            borderWidth: 1,
                            padding: 10,
                            caretSize: 6,
                            cornerRadius: 6,
                            mode: 'index',
                            intersect: false,
                        }
                    }
                }
            });
        } catch (err) {
            console.error('Error fetching debt data:', err);
        }
    }

    function setDebtCreatedFilter(filter: 'today' | 'week' | 'month' | 'year') {
        debtCreatedFilter = filter;
        fetchAndRenderDebtCreatedChart();
    }

</script>

<div class="admin-container">
      <h1>Admin Dashboard</h1>

  {#if isAdmin}
    <section id="stats" class="stats-section">
        <div class="section-header"><h2>Sales Statistics</h2></div>
        <div class="stats-grid">
            <div class="stat-card"><h3>Total Orders</h3><p class="stat-value">{stats.totalOrders}</p></div>
            <div class="stat-card"><h3>Total Revenue</h3><p class="stat-value">R{stats.totalRevenue.toFixed(2)}</p></div>
            <div class="stat-card"><h3>Cash to Collect</h3><p class="stat-value">R{stats.cashToCollect.toFixed(2)}</p></div>
            <div class="stat-card"><h3>Cash Collected Today</h3><p class="stat-value">R{stats.cashCollected.toFixed(2)}</p></div>
            <div class="stat-card"><h3>Cash In</h3><ul class="stat-list"><li>Today: <strong>R{cashIn.today.toFixed(2)}</strong></li><li>This Week: <strong>R{cashIn.week.toFixed(2)}</strong></li><li>This Month: <strong>R{cashIn.month.toFixed(2)}</strong></li></ul></div>
            <div class="stat-card"><h3>Debt Created</h3><ul class="stat-list"><li>Today: <strong>R{debtCreated.today.toFixed(2)}</strong></li><li>This Week: <strong>R{debtCreated.week.toFixed(2)}</strong></li><li>This Month: <strong>R{debtCreated.month.toFixed(2)}</strong></li></ul></div>
            <div class="stat-card"><h3>Top Buyers</h3><ul class="user-list">{#each topBuyers.slice(0, 5) as user}<li><span>{user.name || user.email}</span><span class="user-amount">R{user.total.toFixed(2)}</span></li>{/each}</ul></div>
            <div class="stat-card"><h3>Most Debt</h3><ul class="user-list">{#each mostDebtUsers.slice(0, 5) as user}<li><span>{user.name || user.email}</span><span class="user-amount" style="color: #dc3545;">R{Math.abs(user.balance).toFixed(2)}</span></li>{/each}</ul></div>
            <div class="stat-card"><h3>Most Selling Products</h3><ul class="user-list">{#each topProducts as product}<li><span>{product.name}</span><span class="user-amount">{product.quantity}</span></li>{/each}</ul></div>
        </div>
    </section>

    <section class="charts-section">
      <div class="chart-container">
        <h2>Revenue Over Time</h2>
        <div class="filter-btns">
          <button on:click={() => setRevenueFilter('today')} class:active={revenueFilter==='today'}>Today</button>
          <button on:click={() => setRevenueFilter('week')} class:active={revenueFilter==='week'}>This Week</button>
          <button on:click={() => setRevenueFilter('month')} class:active={revenueFilter==='month'}>This Month</button>
          <button on:click={() => setRevenueFilter('year')} class:active={revenueFilter==='year'}>This Year</button>
        </div>
        <div class="chart-wrapper">
          <canvas id="revenueChart"></canvas>
        </div>
      </div>
      <div class="chart-container">
        <h2>Debt Created vs. Paid</h2>
        <div class="filter-btns">
          <button on:click={() => setDebtCreatedFilter('today')} class:active={debtCreatedFilter==='today'}>Today</button>
          <button on:click={() => setDebtCreatedFilter('week')} class:active={debtCreatedFilter==='week'}>This Week</button>
          <button on:click={() => setDebtCreatedFilter('month')} class:active={debtCreatedFilter==='month'}>This Month</button>
          <button on:click={() => setDebtCreatedFilter('year')} class:active={debtCreatedFilter==='year'}>This Year</button>
        </div>
        <div class="chart-wrapper">
          <canvas id="debtCreatedChart"></canvas>
        </div>
      </div>
    </section>
    {/if}
  </div>
  
<style>
    /* Styles are pruned to only what's necessary for the stats dashboard */
    .admin-container { max-width: 1400px; margin: 0 auto; padding: 2rem; }
    h1 { font-size: 1.5rem; color: #333; }
    .stats-section { margin-bottom: 2rem; }
    .section-header { margin-bottom: 1.5rem; }
    .section-header h2 { font-size: 1.5rem; }
    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1.5rem; }
    .stat-card { background: white; padding: 1.5rem; border-radius: 12px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); text-align: left; border:none; width:100%; }
    .stat-card h3 { margin: 0 0 1rem; color: #6c757d; font-size: 1rem; }
    .stat-value { margin: 0; font-size: 2rem; font-weight: 600; color: #007bff; }
    .user-list, .stat-list { list-style: none; padding: 0; margin: 0; }
    .user-list li, .stat-list li { display: flex; justify-content: space-between; padding: 0.25rem 0; }

    .charts-section {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1.5rem;
      margin-top: 2rem;
    }
    .chart-container {
      background: white;
      padding: 1.5rem;
      border-radius: 12px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
      border: 1px solid #e9ecef;
      display: flex;
      flex-direction: column;
    }
    .chart-container h2 {
      margin: 0 0 1rem;
      font-size: 1.25rem;
      font-weight: 600;
      color: #343a40;
    }

    .chart-wrapper {
      position: relative;
      flex-grow: 1;
      min-height: 300px;
    }

    .filter-btns { display: flex; gap: 0.5rem; margin-bottom: 1.5rem; }
    .filter-btns button { 
      padding: 0.5rem 1rem; 
      border: 1px solid transparent; 
      border-radius: 20px; 
      background: #e9ecef; 
      color: #495057;
      cursor: pointer; 
      font-weight: 500;
      transition: all 0.2s ease;
    }
    .filter-btns button:hover {
      background: #dee2e6;
    }
    .filter-btns button.active { 
      background: #007bff; 
      color: #fff; 
      border-color: #007bff;
      box-shadow: 0 2px 4px rgba(0,123,255,0.2);
    }

    @media (max-width: 900px) {
      .charts-section {
        grid-template-columns: 1fr;
      }
    }
</style>