const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://qboyfdwwrimditugblwo.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'
);

async function main() {
  const loginResult = await supabase.auth.signInWithPassword({
    email: 'hethshah05@gmail.com',
    password: '12345678'
  });

  if (loginResult.error) {
    console.error('Auth error:', loginResult.error.message);
    return;
  }

  console.log('Logged in successfully as admin:', loginResult.data.user.email);

  // Fetch the target order 931d246a-30ef-450f-991f-57504d599859
  const { data: order, error: orderErr } = await supabase
    .from('orders')
    .select('*')
    .eq('id', '931d246a-30ef-450f-991f-57504d599859')
    .single();

  if (orderErr) {
    console.error('Error fetching order:', orderErr);
    return;
  }

  console.log('Fetched order:', {
    id: order.id,
    userId: order.user_id,
    amount: order.total_amount,
    payment_status: order.payment_status,
    order_status: order.order_status,
    payment_source: order.payment_source,
    transaction_id: order.transaction_id
  });

  // Now, let's run the exact logic from order_details_dialog.dart to see what fails!
  try {
    const orderAmount = Number(order.total_amount);
    const orderId = order.id;

    let resolvedUserId = order.user_id;
    if (!resolvedUserId) {
      const { data: userByEmail } = await supabase
        .from('users')
        .select('id')
        .eq('email', order.customer_email || '')
        .maybeSingle();
      resolvedUserId = userByEmail?.id;
    }

    console.log('Resolved user ID:', resolvedUserId);

    const { data: creditAccount, error: accErr } = await supabase
      .from('business_credit_accounts')
      .select('id, available_credit, used_credit, credit_limit')
      .eq('user_id', resolvedUserId || '')
      .maybeSingle();

    if (accErr) {
      console.error('Error fetching credit account:', accErr);
      return;
    }

    console.log('Credit account:', creditAccount);

    if (creditAccount && orderAmount > 0) {
      const accountId = creditAccount.id;

      // Find billing cycle
      const { data: billingCycle, error: bcErr } = await supabase
        .from('billing_cycles')
        .select('id, outstanding_amount, total_payments')
        .eq('credit_account_id', accountId)
        .eq('status', 'open')
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (bcErr) {
        console.error('Error fetching billing cycle:', bcErr);
      }
      console.log('Billing cycle:', billingCycle);

      if (billingCycle) {
        const currentOutstanding = Number(billingCycle.outstanding_amount || 0);
        const currentPayments = Number(billingCycle.total_payments || 0);
        const newOutstanding = Math.max(0, currentOutstanding - orderAmount);
        const newPayments = currentPayments + orderAmount;

        const { error: bcUpdErr } = await supabase
          .from('billing_cycles')
          .update({
            outstanding_amount: newOutstanding,
            total_payments: newPayments,
            updated_at: new Date().toISOString()
          })
          .eq('id', billingCycle.id);

        if (bcUpdErr) {
          console.error('Error updating billing cycle:', bcUpdErr);
        } else {
          console.log('Billing cycle updated successfully.');
        }

        if (newOutstanding <= 0) {
          const { error: bcCloseErr } = await supabase
            .from('billing_cycles')
            .update({
              status: 'closed',
              paid_at: new Date().toISOString(),
              updated_at: new Date().toISOString()
            })
            .eq('id', billingCycle.id);
          if (bcCloseErr) {
            console.error('Error closing billing cycle:', bcCloseErr);
          } else {
            console.log('Billing cycle closed successfully.');
          }
        }
      }

      const currentAvailable = Number(creditAccount.available_credit || 0);
      const currentUsed = Number(creditAccount.used_credit || 0);
      const creditLimit = Number(creditAccount.credit_limit || 0);
      const newUsed = Math.max(0, currentUsed - orderAmount);
      const newAvailable = Math.min(creditLimit, creditLimit - newUsed);

      const accountUpdate = {
        available_credit: newAvailable,
        used_credit: newUsed,
        updated_at: new Date().toISOString()
      };

      if (newUsed <= 0) {
        accountUpdate.is_frozen = false;
        accountUpdate.status = 'active';
        accountUpdate.freeze_reason = null;
        accountUpdate.frozen_at = null;
        accountUpdate.unfrozen_at = new Date().toISOString();
      }

      console.log('Updating business credit account with:', accountUpdate);
      const { error: accUpdErr } = await supabase
        .from('business_credit_accounts')
        .update(accountUpdate)
        .eq('id', accountId);

      if (accUpdErr) {
        console.error('Error updating credit account:', accUpdErr);
      } else {
        console.log('Credit account updated successfully.');
      }

      console.log('Inserting credit usage entry...');
      const { error: cuErr } = await supabase
        .from('credit_usage')
        .insert({
          credit_account_id: accountId,
          order_id: orderId,
          transaction_type: 'credit',
          amount: orderAmount,
          description: `Payment confirmed by admin for Order #${order.order_id || orderId.substring(0, 8).toUpperCase()}`,
          balance_after: newAvailable
        });

      if (cuErr) {
        console.error('Error inserting credit usage:', cuErr);
      } else {
        console.log('Credit usage inserted successfully.');
      }

      console.log('Inserting credit payment entry...');
      const { error: cpErr } = await supabase
        .from('credit_payments')
        .insert({
          credit_account_id: accountId,
          billing_cycle_id: billingCycle?.id || null,
          payment_method: 'bank_transfer',
          amount: orderAmount,
          payment_status: 'completed',
          transaction_id: order.transaction_id,
          payment_date: new Date().toISOString(),
          notes: `Payment verified & confirmed by admin for Order #${order.order_id || orderId.substring(0, 8).toUpperCase()}`
        });

      if (cpErr) {
        console.error('Error inserting credit payment:', cpErr);
      } else {
        console.log('Credit payment inserted successfully.');
      }

      console.log('Running recount RPC...');
      const { error: rpcErr } = await supabase.rpc('recount_business_credit_balances', {
        p_account_id: accountId
      });

      if (rpcErr) {
        console.error('Error running recount RPC:', rpcErr);
      } else {
        console.log('Recount RPC executed successfully.');
      }
    }
  } catch (err) {
    console.error('General error during test:', err);
  }
}

main().catch(console.error);
