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
    import DatePicker from '$lib/components/DatePicker.svelte';
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
    let revenueFilter = 'today';
  
    let debtCreatedChartInstance: ChartType | null = null;
    let debtCreatedFilter: 'today' | 'week' | 'month' | 'year' = 'today';

    let cashCollectedChartInstance: ChartType | null = null;
    let cashCollectedPeriod: 'day' | 'week' | 'month' = 'day';
    let cashCollectedStartDate = new Date();
    let cashCollectedEndDate = new Date();
    
    // Convert dates to string format for DatePicker
    let cashCollectedStartDateStr = '';
    let cashCollectedEndDateStr = '';

    let cashPaidChartInstance: ChartType | null = null;
    let creditChartInstance: ChartType | null = null;
    let debtChartInstance: ChartType | null = null;
    let totalSpentChartInstance: ChartType | null = null;

    let cashPaidPeriod: 'day' | 'week' | 'month' = 'day';
    let cashPaidStartDate = new Date();
    let cashPaidEndDate = new Date();

    let creditPeriod: 'day' | 'week' | 'month' = 'day';
    let creditStartDate = new Date();
    let creditEndDate = new Date();
    let creditStartDateStr = '';
    let creditEndDateStr = '';

    let debtPeriod: 'day' | 'week' | 'month' = 'day';
    let debtStartDate = new Date();
    let debtEndDate = new Date();
    let debtStartDateStr = '';
    let debtEndDateStr = '';

    let totalSpentStartDate = new Date();
    let totalSpentEndDate = new Date();
    let totalSpentStartDateStr = '';
    let totalSpentEndDateStr = '';
    let totalSpentLimit = 10;

    // Set default range to today
    cashCollectedStartDate = new Date();
    cashCollectedEndDate = new Date();
    

    
    // Handle date string changes and convert back to Date objects
    function handleDateStringChange(type: string, isStart: boolean, value: string) {
        if (!value) return; // Don't process empty values
        
        const date = new Date(value + 'T00:00:00'); // Ensure consistent timezone handling
        if (!isNaN(date.getTime())) {
            switch(type) {
                case 'cashCollected':
                    if (isStart) {
                        cashCollectedStartDate = date;
                        cashCollectedStartDateStr = value;
                    } else {
                        cashCollectedEndDate = date;
                        cashCollectedEndDateStr = value;
                    }
                    debouncedCashCollectedUpdate();
                    break;
                case 'credit':
                    if (isStart) {
                        creditStartDate = date;
                        creditStartDateStr = value;
                    } else {
                        creditEndDate = date;
                        creditEndDateStr = value;
                    }
                    debouncedCreditUpdate();
                    break;
                case 'debt':
                    if (isStart) {
                        debtStartDate = date;
                        debtStartDateStr = value;
                    } else {
                        debtEndDate = date;
                        debtEndDateStr = value;
                    }
                    debouncedDebtUpdate();
                    break;
                case 'totalSpent':
                    if (isStart) {
                        totalSpentStartDate = date;
                        totalSpentStartDateStr = value;
                    } else {
                        totalSpentEndDate = date;
                        totalSpentEndDateStr = value;
                    }
                    debouncedTotalSpentUpdate();
                    break;
            }
        }
    }

    Chart.register(neonShadowPlugin);

    onMount(async () => {
      // Initialize date strings from Date objects
      cashCollectedStartDateStr = cashCollectedStartDate.toISOString().split('T')[0];
      cashCollectedEndDateStr = cashCollectedEndDate.toISOString().split('T')[0];
      creditStartDateStr = creditStartDate.toISOString().split('T')[0];
      creditEndDateStr = creditEndDate.toISOString().split('T')[0];
      debtStartDateStr = debtStartDate.toISOString().split('T')[0];
      debtEndDateStr = debtEndDate.toISOString().split('T')[0];
      totalSpentStartDateStr = totalSpentStartDate.toISOString().split('T')[0];
      totalSpentEndDateStr = totalSpentEndDate.toISOString().split('T')[0];

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
        
        let labels, data;

        if (revenueFilter === 'today') {
            labels = chartRpcData.map((d: any) => new Date(d.period).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
            data = chartRpcData.map((d: any) => d.revenue);
        } else if (revenueFilter === 'week') {
            labels = chartRpcData.map((d: any) => new Date(d.period).toLocaleDateString('en-US', { weekday: 'short', day: '2-digit', month: 'short' }));
            data = chartRpcData.map((d: any) => d.revenue);
        } else if (revenueFilter === 'month') {
            labels = chartRpcData.map((d: any) => new Date(d.period).toLocaleDateString('en-US', { day: '2-digit', month: 'short' }));
            data = chartRpcData.map((d: any) => d.revenue);
        } else if (revenueFilter === 'year') {
            labels = chartRpcData.map((d: any) => new Date(d.period).toLocaleDateString('en-US', { month: 'short', year: 'numeric' }));
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
            resizeDelay: 200,
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
                    type: 'category',
                    grid: { display: false },
                    ticks: { 
                        color: '#b2fefa', 
                        font: { weight: 'bold' },
                        maxTicksLimit: window.innerWidth < 768 ? 6 : 12,
                        maxRotation: window.innerWidth < 768 ? 45 : 0
                    }
                } : {
                    grid: { display: false },
                    ticks: { 
                        color: '#b2fefa', 
                        font: { weight: 'bold' },
                        maxTicksLimit: window.innerWidth < 768 ? 6 : 12,
                        maxRotation: window.innerWidth < 768 ? 45 : 0
                    }
                },
                y: { 
                    beginAtZero: true,
                    grid: { color: 'rgba(0,242,254,0.1)' },
                    ticks: { 
                        color: '#b2fefa', 
                        font: { weight: 'bold' },
                        maxTicksLimit: window.innerWidth < 768 ? 5 : 8
                    }
                }
            }
        };

        revenueChartInstance = new Chart(ctx, { type: revenueFilter === 'today' ? 'line' : 'bar', data: chartData, options: chartOptions, plugins: [neonShadowPlugin] });
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
        const { data, error } = await supabase.rpc('get_debt_created_vs_paid', { filter_option: debtCreatedFilter });
        if (error) throw error;
        let labels, debtCreatedData, debtPaidData;
        if (debtCreatedFilter === 'today') {
            labels = data.map((d: any) => new Date(d.period).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
            debtCreatedData = data.map((d: any) => d.debt_created);
            debtPaidData = data.map((d: any) => d.debt_paid);
        } else if (debtCreatedFilter === 'week') {
            labels = data.map((d: any) => new Date(d.period).toLocaleDateString('en-US', { weekday: 'short' }));
            debtCreatedData = data.map((d: any) => d.debt_created);
            debtPaidData = data.map((d: any) => d.debt_paid);
        } else if (debtCreatedFilter === 'month') {
            labels = data.map((d: any) => new Date(d.period).getDate().toString().padStart(2, '0'));
            debtCreatedData = data.map((d: any) => d.debt_created);
            debtPaidData = data.map((d: any) => d.debt_paid);
        } else if (debtCreatedFilter === 'year') {
            labels = data.map((d: any) => new Date(d.period).toLocaleDateString('en-US', { month: 'short' }));
            debtCreatedData = data.map((d: any) => d.debt_created);
            debtPaidData = data.map((d: any) => d.debt_paid);
        }
        const debtCreatedGradient = createNeonGradient(ctx2d, '#ff6a00', '#ee0979');
        const debtPaidGradient = createNeonGradient(ctx2d, '#43e97b', '#38f9d7');
        debtCreatedChartInstance = new Chart(ctx, {
            type: debtCreatedFilter === 'today' ? 'line' : 'bar',
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
                resizeDelay: 200,
                plugins: {
                    legend: { 
                        position: 'top',
                        labels: {
                            color: '#fff',
                            font: { weight: 'bold' },
                            padding: window.innerWidth < 768 ? 10 : 20
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
                    x: {
                        type: 'category',
                        grid: { display: false },
                        ticks: { 
                            color: '#fff', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 6 : 12,
                            maxRotation: window.innerWidth < 768 ? 45 : 0
                        }
                    },
                    y: { 
                        stacked: debtCreatedFilter !== 'today',
                        beginAtZero: true,
                        grid: { color: 'rgba(255,106,0,0.1)' },
                        ticks: { 
                            color: '#fff', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 5 : 8
                        }
                    }
                }
            },
            plugins: [neonShadowPlugin]
        });
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
        let labels, values;
        if (cashCollectedPeriod === 'day') {
            // Use the new event-level function for the day period
            const { data: eventData, error: eventError } = await supabase.rpc('get_cash_collected_events', {
                p_start_date: cashCollectedStartDate.toISOString(),
                p_end_date: cashCollectedEndDate.toISOString()
            });
            if (eventError || !eventData) {
                console.error('Error fetching cash collected events:', eventError);
                return;
            }
            labels = eventData.map((row: any) => new Date(row.period).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
            values = eventData.map((row: any) => Number(row.cash_collected));
        } else if (cashCollectedPeriod === 'week') {
            labels = data.map((row: any) => new Date(row.period_start).toLocaleDateString('en-US', { weekday: 'short' }));
            values = data.map((row: any) => Number(row.cash_collected));
        } else if (cashCollectedPeriod === 'month') {
            labels = data.map((row: any) => new Date(row.period_start).getDate().toString().padStart(2, '0'));
            values = data.map((row: any) => Number(row.cash_collected));
        } else if (cashCollectedPeriod === 'year') {
            labels = data.map((row: any) => new Date(row.period_start).toLocaleDateString('en-US', { month: 'short' }));
            values = data.map((row: any) => Number(row.cash_collected));
        }
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
                resizeDelay: 200,
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
                        type: 'category',
                        grid: { display: false },
                        ticks: { 
                            color: '#b2fefa', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 6 : 12,
                            maxRotation: window.innerWidth < 768 ? 45 : 0
                        }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: 'rgba(67,233,123,0.1)' },
                        ticks: { 
                            color: '#b2fefa', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 5 : 8
                        }
                    }
                }
            },
            plugins: [neonShadowPlugin]
        });
    }

    // Debounced chart update functions
    const debouncedCashCollectedUpdate = debounce(() => {
        fetchAndRenderCashCollectedChart();
    }, 300);
    
    const debouncedCreditUpdate = debounce(() => {
        fetchAndRenderCreditChart();
    }, 300);
    
    const debouncedDebtUpdate = debounce(() => {
        fetchAndRenderDebtChart();
    }, 300);
    
    const debouncedTotalSpentUpdate = debounce(() => {
        fetchAndRenderTotalSpentChart();
    }, 300);
    
    function onCashCollectedFilterChange() {
        debouncedCashCollectedUpdate();
    }
    
    // Functions to set appropriate date ranges based on period
    function updateDateRangeForPeriod(type: string, period: 'day' | 'week' | 'month') {
        const now = new Date();
        let startDate: Date;
        let endDate = new Date(now);
        
        switch(period) {
            case 'day':
                startDate = new Date(now);
                startDate.setHours(0, 0, 0, 0);
                endDate.setHours(23, 59, 59, 999);
                break;
            case 'week':
                startDate = new Date(now);
                startDate.setDate(now.getDate() - 7);
                startDate.setHours(0, 0, 0, 0);
                endDate.setHours(23, 59, 59, 999);
                break;
            case 'month':
                startDate = new Date(now);
                startDate.setDate(now.getDate() - 30);
                startDate.setHours(0, 0, 0, 0);
                endDate.setHours(23, 59, 59, 999);
                break;
            default:
                startDate = new Date(now);
                startDate.setDate(now.getDate() - 7);
        }
        
        switch(type) {
            case 'cashCollected':
                cashCollectedStartDate = startDate;
                cashCollectedEndDate = endDate;
                cashCollectedStartDateStr = startDate.toISOString().split('T')[0];
                cashCollectedEndDateStr = endDate.toISOString().split('T')[0];
                break;
            case 'credit':
                creditStartDate = startDate;
                creditEndDate = endDate;
                creditStartDateStr = startDate.toISOString().split('T')[0];
                creditEndDateStr = endDate.toISOString().split('T')[0];
                break;
            case 'debt':
                debtStartDate = startDate;
                debtEndDate = endDate;
                debtStartDateStr = startDate.toISOString().split('T')[0];
                debtEndDateStr = endDate.toISOString().split('T')[0];
                break;
        }
    }

    // Update charts when periods change and auto-adjust date ranges
    $: {
        if (cashCollectedPeriod) {
            updateDateRangeForPeriod('cashCollected', cashCollectedPeriod);
            debouncedCashCollectedUpdate();
        }
    }

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
        
        let labels, values;
        if (creditPeriod === 'day') {
            labels = data.map((row: any) => new Date(row.period).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
            values = data.map((row: any) => Number(row.credit));
        } else if (creditPeriod === 'week') {
            labels = data.map((row: any) => new Date(row.period).toLocaleDateString('en-US', { weekday: 'short' }));
            values = data.map((row: any) => Number(row.credit));
        } else if (creditPeriod === 'month') {
            labels = data.map((row: any) => new Date(row.period).getDate().toString().padStart(2, '0'));
            values = data.map((row: any) => Number(row.credit));
        }
        
        const gradient = createNeonGradient(ctx2d, '#00f2fe', '#4facfe');
        creditChartInstance = new Chart(ctx, {
            type: 'line',
            data: { 
                labels, 
                datasets: [{ 
                    label: 'Credit', 
                    data: values, 
                    borderColor: '#00f2fe', 
                    backgroundColor: gradient, 
                    borderWidth: 3, 
                    pointBackgroundColor: '#fff', 
                    pointBorderColor: '#00f2fe', 
                    pointRadius: 6, 
                    fill: true, 
                    tension: 0.4 
                }] 
            },
            options: { 
                responsive: true, 
                maintainAspectRatio: false, 
                resizeDelay: 200,
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
                    x: { 
                        type: 'category',
                        grid: { display: false }, 
                        ticks: { 
                            color: '#b2fefa', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 6 : 12,
                            maxRotation: window.innerWidth < 768 ? 45 : 0
                        } 
                    }, 
                    y: { 
                        beginAtZero: true, 
                        grid: { color: 'rgba(0,242,254,0.1)' }, 
                        ticks: { 
                            color: '#b2fefa', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 5 : 8
                        } 
                    } 
                } 
            }, 
            plugins: [neonShadowPlugin] 
        });
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
        
        let labels, values;
        if (debtPeriod === 'day') {
            labels = data.map((row: any) => new Date(row.period).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
            values = data.map((row: any) => Number(row.debt));
        } else if (debtPeriod === 'week') {
            labels = data.map((row: any) => new Date(row.period).toLocaleDateString('en-US', { weekday: 'short' }));
            values = data.map((row: any) => Number(row.debt));
        } else if (debtPeriod === 'month') {
            labels = data.map((row: any) => new Date(row.period).getDate().toString().padStart(2, '0'));
            values = data.map((row: any) => Number(row.debt));
        }
        
        const gradient = createNeonGradient(ctx2d, '#ff6a00', '#ee0979');
        debtChartInstance = new Chart(ctx, {
            type: 'line',
            data: { 
                labels, 
                datasets: [{ 
                    label: 'Debt', 
                    data: values, 
                    borderColor: '#ff6a00', 
                    backgroundColor: gradient, 
                    borderWidth: 3, 
                    pointBackgroundColor: '#fff', 
                    pointBorderColor: '#ff6a00', 
                    pointRadius: 6, 
                    fill: true, 
                    tension: 0.4 
                }] 
            },
            options: { 
                responsive: true, 
                maintainAspectRatio: false, 
                resizeDelay: 200,
                plugins: { 
                    legend: { display: false }, 
                    tooltip: { 
                        backgroundColor: 'rgba(30,30,60,0.95)', 
                        titleColor: '#ff6a00', 
                        bodyColor: '#fff', 
                        borderColor: '#ff6a00', 
                        borderWidth: 2, 
                        padding: 12, 
                        cornerRadius: 8 
                    } 
                }, 
                scales: { 
                    x: { 
                        type: 'category',
                        grid: { display: false }, 
                        ticks: { 
                            color: '#b2fefa', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 6 : 12,
                            maxRotation: window.innerWidth < 768 ? 45 : 0
                        } 
                    }, 
                    y: { 
                        beginAtZero: true, 
                        grid: { color: 'rgba(255,106,0,0.1)' }, 
                        ticks: { 
                            color: '#b2fefa', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 5 : 8
                        } 
                    } 
                } 
            }, 
            plugins: [neonShadowPlugin] 
        });
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
            options: { 
                responsive: true, 
                maintainAspectRatio: false, 
                resizeDelay: 200,
                plugins: { 
                    legend: { display: false }, 
                    tooltip: { 
                        backgroundColor: 'rgba(30,30,60,0.95)', 
                        titleColor: '#b993d6', 
                        bodyColor: '#fff', 
                        borderColor: '#b993d6', 
                        borderWidth: 2, 
                        padding: 12, 
                        cornerRadius: 8 
                    } 
                }, 
                scales: { 
                    x: { 
                        grid: { display: false }, 
                        ticks: { 
                            color: '#b2fefa', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 6 : 12,
                            maxRotation: window.innerWidth < 768 ? 45 : 0
                        } 
                    }, 
                    y: { 
                        beginAtZero: true, 
                        grid: { color: 'rgba(185,147,214,0.1)' }, 
                        ticks: { 
                            color: '#b2fefa', 
                            font: { weight: 'bold' },
                            maxTicksLimit: window.innerWidth < 768 ? 5 : 8
                        } 
                    } 
                } 
            }, plugins: [neonShadowPlugin] });
    }

    // Fetch on mount and whenever filters change
    onMount(() => {
        fetchAndRenderCreditChart();
        fetchAndRenderDebtChart();
        fetchAndRenderTotalSpentChart();
    });

    // Update on change with debounced functions - period changes auto-adjust date ranges
    $: {
        if (creditPeriod) {
            updateDateRangeForPeriod('credit', creditPeriod);
            debouncedCreditUpdate();
        }
    }
    $: {
        if (debtPeriod) {
            updateDateRangeForPeriod('debt', debtPeriod);
            debouncedDebtUpdate();
        }
    }
    $: totalSpentLimit, debouncedTotalSpentUpdate();

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
                <DatePicker 
                  bind:value={cashCollectedStartDateStr} 
                  placeholder="Start date"
                  on:change={(e) => handleDateStringChange('cashCollected', true, e.detail.value)}
                />
              </label>
              <label class="form-label">End Date:
                <DatePicker 
                  bind:value={cashCollectedEndDateStr} 
                  placeholder="End date"
                  on:change={(e) => handleDateStringChange('cashCollected', false, e.detail.value)}
                />
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
                <DatePicker 
                  bind:value={creditStartDateStr} 
                  placeholder="Start date"
                  on:change={(e) => handleDateStringChange('credit', true, e.detail.value)}
                />
              </label>
              <label class="form-label">End Date:
                <DatePicker 
                  bind:value={creditEndDateStr} 
                  placeholder="End date"
                  on:change={(e) => handleDateStringChange('credit', false, e.detail.value)}
                />
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
                <DatePicker 
                  bind:value={debtStartDateStr} 
                  placeholder="Start date"
                  on:change={(e) => handleDateStringChange('debt', true, e.detail.value)}
                />
              </label>
              <label class="form-label">End Date:
                <DatePicker 
                  bind:value={debtEndDateStr} 
                  placeholder="End date"
                  on:change={(e) => handleDateStringChange('debt', false, e.detail.value)}
                />
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
                <DatePicker 
                  bind:value={totalSpentStartDateStr} 
                  placeholder="Start date"
                  on:change={(e) => handleDateStringChange('totalSpent', true, e.detail.value)}
                />
              </label>
              <label class="form-label">End Date:
                <DatePicker 
                  bind:value={totalSpentEndDateStr} 
                  placeholder="End date"
                  on:change={(e) => handleDateStringChange('totalSpent', false, e.detail.value)}
                />
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
    min-width: 120px;
  }

  .chart-wrapper {
    position: relative;
    height: 300px;
    width: 100%;
    min-height: 250px;
    overflow: hidden;
  }

  .chart-wrapper canvas {
    max-width: 100% !important;
    height: auto !important;
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

  /* Enhanced mobile responsiveness */
  @media (max-width: 1200px) {
    .admin-container {
      padding: 1rem;
    }
    
    .grid-3 {
      grid-template-columns: repeat(2, 1fr);
    }

    .chart-wrapper {
      height: 280px;
    }
  }

  @media (max-width: 768px) {
    .admin-container {
      padding: 0.75rem;
    }

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
      gap: 0.75rem;
    }

    .filters label {
      min-width: auto;
      width: 100%;
    }
    
    .filter-btns {
      flex-direction: column;
      gap: 0.5rem;
    }



    .chart-wrapper {
      height: 250px;
      min-height: 200px;
    }

    /* Make cards more mobile-friendly */
    .glass {
      margin-bottom: 1rem;
    }

    .card-body {
      padding: 1rem;
    }

    .card-header {
      padding: 0.75rem 1rem;
    }

    .card-header h2 {
      font-size: 1.1rem;
    }

    /* Improve stats grid for mobile */
    .glass-light {
      padding: 1rem !important;
    }

    .glass-light h3 {
      font-size: 0.9rem;
      margin-bottom: 0.5rem;
    }

    .glass-light p {
      font-size: 1.2rem !important;
    }

    .user-list {
      font-size: 0.85rem;
    }
  }

  @media (max-width: 480px) {
    .admin-container {
      padding: 0.5rem;
    }

    .chart-wrapper {
      height: 220px;
      min-height: 180px;
    }

    .text-2xl {
      font-size: 1.2rem;
    }

    .starry-toggle {
      padding: 0.4rem 1rem;
      font-size: 1rem;
    }

    .glass-light p {
      font-size: 1.1rem !important;
    }

    .filters label {
      font-size: 0.9rem;
    }

    .form-control,
    .form-select {
      font-size: 0.9rem;
      padding: 0.5rem;
    }
  }

  /* Ensure charts scale properly */
  @media (max-width: 600px) {
    .chart-wrapper {
      position: relative;
      width: 100%;
      height: 0;
      padding-bottom: 60%; /* 16:10 aspect ratio for mobile */
    }

    .chart-wrapper canvas {
      position: absolute !important;
      top: 0;
      left: 0;
      width: 100% !important;
      height: 100% !important;
    }
  }
</style>