-- ============================================================
-- QuickConvert — Supabase SQL Schema
-- Exécuter dans le SQL Editor de Supabase
-- ============================================================

-- ── Extension UUID ────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Table profiles ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email           TEXT,
  is_premium      BOOLEAN DEFAULT FALSE,
  conversions_today INTEGER DEFAULT 0,
  last_reset      TIMESTAMPTZ DEFAULT NOW(),
  premium_expires_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ── Table conversion_logs ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.conversion_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  type        TEXT NOT NULL,
  success     BOOLEAN DEFAULT TRUE,
  input_size  INTEGER,
  output_size INTEGER,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.conversion_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own logs"
  ON public.conversion_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own logs"
  ON public.conversion_logs FOR SELECT
  USING (auth.uid() = user_id);

-- ── Storage bucket ────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('converted-files', 'converted-files', false)
ON CONFLICT DO NOTHING;

CREATE POLICY "Users can upload own files"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'converted-files' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view own files"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'converted-files' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ── Fonction: incrémenter les conversions ─────────────────────────────────
CREATE OR REPLACE FUNCTION increment_conversions_today(user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Reset si nouveau jour
  UPDATE public.profiles
  SET conversions_today = CASE
    WHEN DATE(last_reset) < CURRENT_DATE THEN 1
    ELSE conversions_today + 1
  END,
  last_reset = CASE
    WHEN DATE(last_reset) < CURRENT_DATE THEN NOW()
    ELSE last_reset
  END
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Trigger: créer un profil à l'inscription ──────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, created_at)
  VALUES (NEW.id, NEW.email, NOW())
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── Vue: analytics conversions ────────────────────────────────────────────
CREATE OR REPLACE VIEW public.conversion_stats AS
SELECT
  type,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE success = TRUE) AS successes,
  COUNT(*) FILTER (WHERE success = FALSE) AS failures,
  AVG(input_size) AS avg_input_size,
  AVG(output_size) AS avg_output_size,
  DATE(created_at) AS day
FROM public.conversion_logs
GROUP BY type, DATE(created_at)
ORDER BY day DESC;
