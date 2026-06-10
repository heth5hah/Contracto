# Quick Deployment Reference - Account Deletion Feature

## 🚀 Deploy in 3 Steps

### 1. Login to Supabase
```bash
supabase login
```

### 2. Link Your Project
```bash
cd /Users/kiviro/Documents/Client\ Works/Najmi/Najmi/najmi_app
supabase link --project-ref qboyfdwwrimditugblwo
```

**Find your PROJECT_REF:**
- Dashboard → Settings → General → Reference ID

### 3. Deploy Edge Function
```bash
supabase functions deploy delete-user
```

**Expected output:**
```
✓ Deploying function delete-user
✓ Deployed successfully
```

---

## ✅ Verify Deployment

```bash
# List all functions
supabase functions list

# View logs
supabase functions logs delete-user
```

---

## 🧪 Test the Feature

### From the App:
1. Create a test account
2. Go to **Profile** → Scroll down
3. Tap **Delete Account**
4. Follow the 2-step confirmation
5. Verify account is deleted

### Check Deletion:
- User removed from `users` table ✓
- Wishlist cleared ✓
- Addresses deleted ✓
- Quote requests removed ✓
- Orders deleted ✓
- Auth account removed ✓

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Function not found | Run `supabase functions deploy delete-user` |
| Auth error | Run `supabase login` again |
| Permission denied | Check service role key in Dashboard |
| Edge function fails | Check logs: `supabase functions logs delete-user` |

---

## 📚 Full Documentation

- **Detailed Guide**: [EDGE_FUNCTION_DEPLOYMENT_GUIDE.md](./EDGE_FUNCTION_DEPLOYMENT_GUIDE.md)
- **Implementation Details**: [ACCOUNT_DELETION_IMPLEMENTATION.md](./ACCOUNT_DELETION_IMPLEMENTATION.md)

---

## 🆘 Need Help?

1. Check logs: `supabase functions logs delete-user --tail`
2. Verify function exists: `supabase functions list`
3. Test manually: Dashboard → Edge Functions → delete-user → Invoke
4. Check database tables exist and RLS policies are correct

---

## 📝 Files Changed

- ✅ `lib/features/auth/data/services/user_service.dart` - Added deleteAccount()
- ✅ `lib/features/profile/presentation/screens/profile_screen.dart` - Added UI
- ✅ `supabase/functions/delete-user/index.ts` - Edge Function

Ready to go! 🎉















