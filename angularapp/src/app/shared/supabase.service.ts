import { Injectable } from '@angular/core';
import { createClient, Session, SupabaseClient } from '@supabase/supabase-js';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class SupabaseService {
  readonly client: SupabaseClient;

  constructor() {
    this.client = createClient(environment.supabaseUrl, environment.supabaseKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
        storageKey: 'territorytool.supabase.auth'
      }
    });
  }

  async getSession(): Promise<Session | null> {
    const { data } = await this.client.auth.getSession();
    return data.session;
  }

  async getAccessToken(): Promise<string | null> {
    return (await this.getSession())?.access_token ?? null;
  }

  // Forces a token refresh so newly-changed JWT claims (e.g. congregation_id,
  // app_role) take effect. Returns the refreshed access token.
  async refreshSession(): Promise<string | null> {
    const { data, error } = await this.client.auth.refreshSession();
    if (error) throw error;
    return data.session?.access_token ?? null;
  }

  async rpc<T>(fn: string, args?: Record<string, any>): Promise<T> {
    const { data, error } = await this.client.rpc(fn, args);
    if (error) throw error;
    return data as T;
  }

  async invoke<T>(functionName: string, body?: Record<string, any>): Promise<T> {
    const { data, error } = await this.client.functions.invoke<T>(functionName, { body });
    if (error) throw error;
    return data as T;
  }
}
