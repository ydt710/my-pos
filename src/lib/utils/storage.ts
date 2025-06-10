import { supabase } from '$lib/supabase';

export async function uploadSignature(file: File): Promise<string> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const fileExt = file.name.split('.').pop();
  const fileName = `${Date.now()}.${fileExt}`;
  const filePath = `${user.id}/${fileName}`;

  const { error: uploadError } = await supabase.storage
    .from('signatures')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: false
    });

  if (uploadError) throw uploadError;

  const { data: { signedUrl } } = await supabase.storage
    .from('signatures')
    .createSignedUrl(filePath, 3600);

  if (!signedUrl) throw new Error('Failed to get signed URL');

  return signedUrl;
}

export async function uploadIdImage(file: File): Promise<string> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User not authenticated');

  const fileExt = file.name.split('.').pop();
  const fileName = `${Date.now()}.${fileExt}`;
  const filePath = `${user.id}/${fileName}`;

  const { error: uploadError } = await supabase.storage
    .from('id_images')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: false
    });

  if (uploadError) throw uploadError;

  const { data: { signedUrl } } = await supabase.storage
    .from('id_images')
    .createSignedUrl(filePath, 3600);

  if (!signedUrl) throw new Error('Failed to get signed URL');

  return signedUrl;
}

export async function getSignedUrl(bucket: 'signatures' | 'id_images', path: string): Promise<string> {
  const { data: { signedUrl } } = await supabase.storage
    .from(bucket)
    .createSignedUrl(path, 3600);

  if (!signedUrl) throw new Error('Failed to get signed URL');

  return signedUrl;
} 