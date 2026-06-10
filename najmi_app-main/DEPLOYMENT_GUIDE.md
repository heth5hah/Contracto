# Quote Request System - Deployment Guide

## Overview
This guide explains how to safely deploy the new quote request system alongside your existing database without disrupting current functionality.

## Prerequisites

### 1. Database Access
- Access to your Supabase project
- Ability to run SQL migrations
- Backup of current database (recommended)

### 2. Current System Status
- Existing `quotations` table with data
- Users table with `role` field
- Products table with pricing information

### 3. App Updates
- Updated Flutter app with new quotation service
- Updated admin panel with new quotation management

## Deployment Steps

### Step 1: Database Backup (Recommended)
```sql
-- Create backup of existing quotations
CREATE TABLE quotations_backup AS 
SELECT * FROM quotations;

-- Verify backup
SELECT COUNT(*) FROM quotations_backup;
```

### Step 2: Run Migration Script
```bash
# Execute the migration script
psql -h your-supabase-host -U your-username -d your-database -f admin/add_quote_requests_table.sql
```

**Or via Supabase Dashboard:**
1. Go to SQL Editor in Supabase
2. Copy and paste the contents of `admin/add_quote_requests_table.sql`
3. Execute the script

### Step 3: Verify Migration
```sql
-- Check if new tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('quote_requests', 'quotes', 'quote_request_items', 'quote_items');

-- Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('quote_requests', 'quotes', 'quote_request_items', 'quote_items');

-- Check if policies were created
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('quote_requests', 'quotes', 'quote_request_items', 'quote_items');
```

### Step 4: Test New System
```sql
-- Test creating a quote request (as a test user)
INSERT INTO quote_requests (user_id, product_id, product_name, category, status, notes)
VALUES (
    'test-user-id',
    'test-product-id',
    'Test Product',
    'Test Category',
    'pending',
    'Test quote request'
);

-- Verify the insert worked
SELECT * FROM quote_requests WHERE product_name = 'Test Product';

-- Clean up test data
DELETE FROM quote_requests WHERE product_name = 'Test Product';
```

### Step 5: Deploy App Updates
1. **Flutter App**: Deploy the updated app with new quotation service
2. **Admin Panel**: Update the admin panel with new quotation management
3. **Test**: Verify both old and new systems work together

## System Architecture After Deployment

### New Tables
```
quote_requests          ← Customer quote requests
├── quote_request_items ← Individual items with quantities
quotes                 ← Admin-generated quotes
└── quote_items        ← Individual item pricing
```

### Existing Tables (Preserved)
```
quotations             ← Legacy quotations (unchanged)
users                  ← User management (unchanged)
products               ← Product catalog (unchanged)
```

### Data Flow
1. **New System**: `quote_requests` → `quotes` → `quote_items`
2. **Old System**: `quotations` (continues to work)
3. **Combined View**: App shows both systems in quotations screen

## Testing Checklist

### Database Level
- [ ] New tables created successfully
- [ ] RLS policies working correctly
- [ ] Foreign key constraints valid
- [ ] Indexes created for performance

### App Level
- [ ] Quote requests can be created
- [ ] Admin panel shows new requests
- [ ] Quotes can be generated
- [ ] Old quotations still visible
- [ ] Both systems display correctly

### Admin Panel
- [ ] Can view quote requests
- [ ] Can generate quotes
- [ ] Can set pricing for quality options
- [ ] Can manage quote statuses

## Rollback Plan

### If Issues Occur
```sql
-- Drop new tables (in reverse order)
DROP TABLE IF EXISTS quote_items;
DROP TABLE IF EXISTS quotes;
DROP TABLE IF EXISTS quote_request_items;
DROP TABLE IF EXISTS quote_requests;

-- Drop function and triggers
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Remove migration record
DELETE FROM schema_migrations WHERE version = 'quote_requests_v1';
```

### App Rollback
1. Revert to previous app version
2. Restore old quotation service
3. Remove new quotation screen updates

## Monitoring After Deployment

### Key Metrics to Watch
1. **Quote Request Volume**: Number of new requests vs. old quotations
2. **System Performance**: Response times for new vs. old systems
3. **Error Rates**: Any issues with new tables or policies
4. **User Adoption**: How many users use new vs. old system

### Database Monitoring
```sql
-- Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE tablename IN ('quote_requests', 'quotes', 'quote_request_items', 'quote_items', 'quotations');

-- Check recent activity
SELECT 
    table_name,
    COUNT(*) as record_count,
    MAX(created_at) as latest_record
FROM (
    SELECT 'quote_requests' as table_name, created_at FROM quote_requests
    UNION ALL
    SELECT 'quotations' as table_name, created_at FROM quotations
) combined
GROUP BY table_name;
```

## Troubleshooting

### Common Issues

#### 1. RLS Policy Errors
```sql
-- Check if user has proper role
SELECT role FROM users WHERE id = auth.uid();

-- Verify policy exists
SELECT * FROM pg_policies WHERE tablename = 'quote_requests';
```

#### 2. Foreign Key Constraint Errors
```sql
-- Check if referenced records exist
SELECT id FROM users WHERE id = 'user-id-here';
SELECT id FROM products WHERE id = 'product-id-here';
```

#### 3. Permission Denied Errors
```sql
-- Check table permissions
SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name = 'quote_requests';
```

### Performance Issues
```sql
-- Check if indexes are being used
EXPLAIN ANALYZE SELECT * FROM quote_requests WHERE user_id = 'user-id';

-- Check table statistics
ANALYZE quote_requests;
ANALYZE quotes;
```

## Future Enhancements

### Phase 2 Features (After Stable Deployment)
1. **Email Notifications**: Automatic emails for quote status changes
2. **SMS Alerts**: SMS notifications for urgent requests
3. **Quote Templates**: Customizable quote formats
4. **Analytics Dashboard**: Quote performance metrics

### Migration Strategy
1. **Gradual Migration**: Move users to new system over time
2. **Data Migration**: Eventually migrate old quotations to new system
3. **System Deprecation**: Phase out old system after full migration

## Support and Maintenance

### Regular Maintenance
- Monitor table growth and performance
- Update statistics regularly
- Review and optimize RLS policies
- Backup new tables along with existing ones

### Documentation Updates
- Update API documentation
- Maintain deployment procedures
- Document any customizations made

## Conclusion

The new quote request system is designed to work alongside your existing infrastructure without disruption. The deployment process is safe and reversible, allowing you to test the new functionality while maintaining current operations.

Key benefits of this approach:
- **Zero Downtime**: Existing system continues to work
- **Gradual Migration**: Users can adopt new system at their own pace
- **Risk Mitigation**: Easy rollback if issues arise
- **Future Proof**: Foundation for advanced quote management features

Follow this guide step-by-step, and you'll have a robust, modern quote request system that enhances your business operations while preserving your existing data and functionality.
