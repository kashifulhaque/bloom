// Deletes the caller's Bloom sync account: their encrypted records, their
// wrapped key, their sessions, and finally the auth user itself.
//
// POST /functions/v1/delete-account with the user's access token. Returns 204
// on success. The service role key comes from the function's environment
// (SUPABASE_SECRET_KEYS on the hosted platform); it never ships in the app.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

function error(status: number, code: string, message: string): Response {
  return Response.json({ error: { code, message } }, { status });
}

export default {
  // auth: "user" verifies the caller's JWT against the project's signing keys
  // and answers CORS preflight requests. The handler runs only for a valid user.
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return error(405, "method_not_allowed", "Use POST.");
    }
    const userId = ctx.userClaims?.id;
    if (!userId) {
      return error(401, "no_user", "Sign in again, then try again.");
    }

    // 1. Delete the user's rows with their own RLS-scoped client, so this step
    //    can only ever touch rows the caller owns. The foreign keys also
    //    cascade from auth.users, but deleting first keeps the data gone even
    //    if a later step fails.
    for (const table of ["sync_records", "sync_keys"]) {
      const { error: e } = await ctx.supabase.from(table).delete().eq("user_id", userId);
      if (e) {
        console.error(`delete-account: deleting ${table} failed`, e.code);
        return error(500, "delete_rows_failed", "Couldn't delete the synced data. Try again.");
      }
    }

    // 2. Revoke every refresh token. Deleting a user doesn't invalidate access
    //    tokens that were already issued; they expire on their own (keep the
    //    project's JWT expiry short).
    const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
    const { error: signOutError } = await ctx.supabaseAdmin.auth.admin.signOut(jwt, "global");
    if (signOutError) console.warn("delete-account: global sign-out failed", signOutError.status);

    // 3. Delete the auth user with the admin API.
    const { error: deleteError } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error("delete-account: deleting the user failed", deleteError.status);
      return error(500, "delete_user_failed", "Your synced data was deleted, but the account wasn't. Try again.");
    }

    return new Response(null, { status: 204 });
  }),
};
