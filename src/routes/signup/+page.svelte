<script lang="ts">
    import { supabase } from '$lib/supabase';
    import { goto } from '$app/navigation';
    import StarryBackground from '$lib/components/StarryBackground.svelte';
    import { onMount, onDestroy } from 'svelte';
    import { fade } from 'svelte/transition';
    import { uploadSignature, uploadIdImage } from '$lib/utils/storage';
    import SignaturePad from '$lib/components/SignaturePad.svelte';
    import { showSnackbar } from '$lib/stores/snackbarStore';
    // @ts-ignore
    let html2pdf: any = null;
  
    let email = '';
    let password = '';
    let displayName = '';
    let phoneNumber = '';
    let error = '';
    let loading = false;
    let success = '';
    let logoUrl = '';

    // New fields for first and last name
    let firstName = '';
    let lastName = '';

    // For the signed contract download
    let signedContractDownloadUrl: string | null = null;

    // Signature and ID capture
    let signatureDataUrl = '';
    let idImageFile: File | null = null;
    let idImagePreview = '';
    let isCapturingId = false;
    let signaturePad: SignaturePad;
    let showCameraModal = false;
    let videoStream: MediaStream | null = null;
    let videoElement: HTMLVideoElement;
    let isCameraReady = false;
    let isSignatureEmpty = true;

    onMount(async () => {
      try {
        const { data } = supabase.storage.from('route420').getPublicUrl('logo.png');
        logoUrl = data.publicUrl;
        if (typeof window !== 'undefined') {
          // @ts-ignore
          html2pdf = (await import('html2pdf.js')).default;
        }
      } catch (err) {
        console.error('Error getting logo URL:', err);
      }
    });

    // Helper to convert File to Data URL
    function fileToDataUrl(file: File): Promise<string> {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result as string);
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
    }

    // Compress and resize image before embedding in PDF
    async function compressImage(file: File, maxWidth = 800, quality = 0.7): Promise<string> {
      return new Promise((resolve, reject) => {
        const img = new Image();
        const reader = new FileReader();
        reader.onload = (e) => {
          img.onload = () => {
            const scale = Math.min(1, maxWidth / img.width);
            const canvas = document.createElement('canvas');
            canvas.width = img.width * scale;
            canvas.height = img.height * scale;
            const ctx = canvas.getContext('2d');
            if (!ctx) return reject('No canvas context');
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            resolve(canvas.toDataURL('image/jpeg', quality));
          };
          img.onerror = reject;
          img.src = e.target?.result as string;
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
    }

    async function handleIdImageCapture(event: Event) {
      const input = event.target as HTMLInputElement;
      if (!input.files?.length) return;
      
      const file = input.files[0];
      if (!file) return;
      
      if (!file.type.startsWith('image/')) {
        showSnackbar('Please upload an image file');
        return;
      }
      
      if (file.size > 5 * 1024 * 1024) {
        showSnackbar('Image size should be less than 5MB');
        return;
      }
      
      idImageFile = file;
      idImagePreview = await compressImage(file, 800, 0.7);
    }

    async function startCamera() {
      try {
        videoStream = await navigator.mediaDevices.getUserMedia({ 
          video: { 
            facingMode: 'environment',
            width: { ideal: 1280 },
            height: { ideal: 720 }
          } 
        });
        
        showCameraModal = true;
        
        // Wait for the next tick to ensure video element is mounted
        await new Promise(resolve => setTimeout(resolve, 0));
        
        if (videoElement) {
          videoElement.srcObject = videoStream;
          videoElement.onloadedmetadata = () => {
            videoElement.play();
            isCameraReady = true;
          };
        }
      } catch (err) {
        console.error('Error accessing camera:', err);
        showSnackbar('Could not access camera. Please check your permissions.');
        showCameraModal = false;
      }
    }

    function stopCamera() {
      if (videoStream) {
        videoStream.getTracks().forEach(track => track.stop());
        videoStream = null;
      }
      isCameraReady = false;
      showCameraModal = false;
    }

    function capturePhoto() {
      if (!isCameraReady || !videoElement) return;

      const canvas = document.createElement('canvas');
      canvas.width = videoElement.videoWidth;
      canvas.height = videoElement.videoHeight;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      // Draw the current video frame
      ctx.drawImage(videoElement, 0, 0);
      
      // Convert to blob
      canvas.toBlob(async (blob) => {
        if (!blob) return;
        
        // Create a file from the blob
        const file = new File([blob], 'id-photo.jpg', { type: 'image/jpeg' });
        idImageFile = file;
        idImagePreview = await compressImage(file, 800, 0.7); // Use compressed Data URL
        
        // Stop camera and close modal
        stopCamera();
      }, 'image/jpeg', 0.95);
    }

    // Clean up camera on component destroy
    onDestroy(() => {
      stopCamera();
    });

    function handleSignatureChange(event: CustomEvent<{ isEmpty: boolean }>) {
      isSignatureEmpty = event.detail.isEmpty;
      if (!isSignatureEmpty) {
        signatureDataUrl = signaturePad.getSignatureData();
      }
    }

    // Debounce utility for signature pad redraw
    function debounce<T extends (...args: any[]) => void>(fn: T, delay: number): T {
      let timeout: ReturnType<typeof setTimeout>;
      return function(this: any, ...args: any[]) {
        clearTimeout(timeout);
        timeout = setTimeout(() => fn.apply(this, args), delay);
      } as T;
    }

    // Debounced signature change handler
    const debouncedSignatureChange = debounce(handleSignatureChange, 50);

    async function signup() {
      if (isSignatureEmpty) {
        showSnackbar('Please provide your signature');
        return;
      }

      if (!idImageFile) {
        showSnackbar('Please provide your ID image');
        return;
      }

      loading = true;
      error = '';
      success = '';
      signedContractDownloadUrl = null;

      try {
        // Create user account first
        const { data: authData, error: authError } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              display_name: displayName,
              phone_number: phoneNumber
            }
          }
        });

        if (authError) throw authError;
        if (!authData.user) throw new Error('No user data returned');

        // Sign in the user immediately
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email,
          password
        });

        if (signInError) throw signInError;

        // Convert signature data URL to blob
        const signatureBlob = await fetch(signatureDataUrl).then(r => r.blob());
        const signatureFile = new File([signatureBlob], 'signature.png', { type: 'image/png' });

        // Upload signature and ID image
        const [signatureUrl, idImageUrl] = await Promise.all([
          uploadSignature(signatureFile),
          uploadIdImage(idImageFile)
        ]);

        // --- Generate and upload signed contract PDF ---
        let contractFilePath: string | null = null; 
        try {
          contractFilePath = await generateSignedContract(
            firstName,
            lastName,
            signatureDataUrl,
            authData.user.id
          );
          if (!contractFilePath) {
            showSnackbar('Warning: Could not generate contract. Please contact support.');
          }
        } catch (pdfError) {
          console.error('Error generating or uploading signed contract:', pdfError);
          showSnackbar('Warning: Could not generate contract. Please contact support.');
          contractFilePath = null;
        }

        // Upsert profile with contract file path
        const { error: profileError } = await supabase
          .from('profiles')
          .upsert(
            {
              auth_user_id: authData.user.id,
              email,
              display_name: displayName,
              phone_number: phoneNumber,
              signature_url: signatureUrl,
              id_image_url: idImageUrl,
              first_name: firstName,
              last_name: lastName,
              signed_contract_url: contractFilePath
            },
            { onConflict: 'auth_user_id' }
          );

        if (profileError) throw profileError;

        signedContractDownloadUrl = contractFilePath; // Assign the generated URL here
        success = 'Account created successfully!'; // Set success message

        // If no download URL, automatically navigate
        if (!signedContractDownloadUrl) {
          goto('/'); // Immediately navigate if no download URL
        }

      } catch (err) {
        console.error('Error during signup:', err);
        showSnackbar(err instanceof Error ? err.message : 'An error occurred during signup');
        success = '';
        signedContractDownloadUrl = null;
      } finally {
        loading = false;
        // Clear form fields here to ensure it always happens when loading is false
        email = '';
        password = '';
        displayName = '';
        phoneNumber = '';
        firstName = '';
        lastName = '';
        signatureDataUrl = '';
        idImageFile = null;
        idImagePreview = '';
        isSignatureEmpty = true;
        if (signaturePad) signaturePad.clear();
      }
    }

    async function handleDownloadClick() {
      if (signedContractDownloadUrl) {
        const { data, error } = await supabase.storage
          .from('signed.contracts')
          .createSignedUrl(signedContractDownloadUrl, 600);
        if (data && data.signedUrl) {
          window.open(data.signedUrl, '_blank');
        goto('/');
        } else {
          showSnackbar('Could not generate download link. Please try again.');
        }
      }
    }

    async function generateSignedContract(firstName: string, lastName: string, signatureDataUrl: string, userId: string): Promise<string | null> {
      if (!html2pdf) {
        throw new Error('PDF generation is only available in the browser.');
      }
      const element = document.getElementById('contract-template');
      if (!element) {
        console.error('Contract template not found');
        return null;
      }
      const opt = {
        margin: 0.5,
        filename: 'contract.pdf',
        image: { type: 'jpeg', quality: 0.7 }, // Lowered quality for smaller PDF
        html2canvas: { scale: 2 },
        jsPDF: { unit: 'in', format: 'a4', orientation: 'portrait' }
      };
      const pdfBlob = await html2pdf().from(element).set(opt).outputPdf('blob');
      const filename = `${userId}/${Date.now()}.pdf`;
        const { data: uploadData, error: uploadError } = await supabase.storage
        .from('signed.contracts')
        .upload(filename, pdfBlob, { contentType: 'application/pdf', upsert: false });
        if (uploadError) {
          console.error('Error uploading signed PDF:', uploadError);
          return null;
        }
      return filename;
    }
  </script>
  
  <StarryBackground />
  
  <div class="auth-container">
    <div class="auth-card">
      {#if logoUrl}
        <img src={logoUrl} alt="Logo" class="logo" />
      {/if}
      <h1 style="text-align:center;color:wheat">Create Account</h1>
      <h1 style="text-align:center;color:wheat">Join us today</h1>
      {#if signedContractDownloadUrl}
        <div class="success" transition:fade>
          <p>Account created successfully!</p>
          <p>Your contract is ready.</p>
          <button type="button" class="submit-btn" on:click={handleDownloadClick}>
            Download Signed Contract
          </button>
          <button type="button" class="link-btn" on:click={() => goto('/')} style="margin-top: 1rem;">Go to Home</button>
        </div>
      {:else if success}
        <div class="success" transition:fade>
          <p>{success}</p>
          <p>Redirecting to home...</p>
        </div>
      {:else}
        <form on:submit|preventDefault={signup}>
          <div class="form-group">
            <label for="firstName">First Name</label>
            <input
              id="firstName"
              type="text"
              bind:value={firstName}
              placeholder="Enter your first name"
              required
            />
          </div>

          <div class="form-group">
            <label for="lastName">Last Name</label>
            <input
              id="lastName"
              type="text"
              bind:value={lastName}
              placeholder="Enter your last name"
              required
            />
          </div>

          <div class="form-group">
            <label for="displayName">Display Name</label>
            <input
              id="displayName"
              type="text"
              bind:value={displayName}
              placeholder="Enter your display name"
              required
            />
          </div>

          <div class="form-group">
            <label for="phoneNumber">Phone Number</label>
            <input
              id="phoneNumber"
              type="tel"
              bind:value={phoneNumber}
              placeholder="Enter your phone number"
              required
            />
          </div>

          <div class="form-group">
            <label for="email">Email</label>
            <input
              id="email"
              type="email"
              bind:value={email}
              placeholder="Enter your email"
              required
              autocomplete="username"
            />
          </div>

          <div class="form-group">
            <label for="password">Password</label>
            <input
              id="password"
              type="password"
              bind:value={password}
              placeholder="Create a password"
              required
              autocomplete="new-password"
              minlength="6"
            />
            <small class="password-hint">Password must be at least 6 characters long</small>
          </div>

          <div class="form-group">
            <label for="signature-pad">Signature</label>
            <div class="signature-container" id="signature-pad">
              <SignaturePad
                bind:this={signaturePad}
                width={320}
                height={160}
                on:change={debouncedSignatureChange}
              />
              {#if isSignatureEmpty}
                <div class="signature-hint">Please sign above</div>
              {/if}
            </div>
          </div>

          <div class="form-group">
            <label for="idImage">ID/Driver's License</label>
            <div class="upload-area" class:active={isCapturingId}>
              {#if idImagePreview}
                <div class="preview-container">
                  <img src={idImagePreview} alt="ID preview" class="preview-image" />
                  <button type="button" class="remove-btn" on:click={() => {
                    idImageFile = null;
                    idImagePreview = '';
                  }}>×</button>
                </div>
              {:else}
                <div class="upload-options">
                  <label for="idImage" class="upload-label">
                    <div class="upload-icon">📁</div>
                    <span>Upload File</span>
                    <span class="upload-hint">PNG, JPG up to 5MB</span>
                    <input
                      type="file"
                      id="idImage"
                      accept="image/*"
                      on:change={handleIdImageCapture}
                      class="file-input"
                    />
                  </label>
                  <button type="button" class="camera-btn" on:click={startCamera}>
                    <div class="upload-icon">📷</div>
                    <span>Take Photo</span>
                  </button>
                </div>
              {/if}
            </div>
          </div>

          <!-- Agreement box moved here, above the Create Account button -->
          <div class="agreement-content">
            <h2 style="text-align:center;">Membership Agreement Preview</h2>
            <div>
              <div id="contract-template">
                <h2 style="text-align:center;">MEMBERSHIP AGREEMENT</h2>
                <p><strong>Between:</strong><br>
                Route 420 WP<br>
                ("the Club")<br>
                and<br>
                <strong>{firstName} {lastName}</strong><br>
                ("the Member")</p>
                <hr>
                <p><strong>PREAMBLE</strong><br>
                WHEREAS the Member wishes to use the Club's private facilities for the cultivation of crops for personal use, as the Member lacks the
                necessary knowledge, skills, space, or infrastructure to do so; and<br>
                WHEREAS the Member has leased a designated cultivation space through the Club as described in Annexure A (Independent Contractor
                Agreement), with cultivation services performed by a designated Cultivating Member on behalf of the Member for personal use; and<br>
                WHEREAS neither the Club, service provider, nor Cultivating Member shall sell, trade, or commercialize the crop, but solely provide services
                in cultivating the Member's crop, which remains the Member's property at all times.</p>
                <p><strong>NOW THEREFORE, the Parties agree to the following:</strong></p>
                <ol style="font-size: 0.95em;">
                  <li><strong>REGISTRATION</strong>
                    <ol>
                      <li>The Member shall complete the required Membership Application Form, providing valid identification confirming that they are 18 years or older.</li>
                      <li>Upon approval, the Member will receive a unique username and password for the Club's member portal.</li>
                      <li>By registering, the Member becomes a private member of the Club and gains access to private cultivation services and secure storage of their product.</li>
                    </ol>
                  </li>
                  <li><strong>CLUB MEMBERSHIP SERVICES</strong>
                    <ol>
                      <li>The Club provides cultivation services to the Member in exchange for a Membership Fee.</li>
                      <li>These services are exclusively for cultivating crops for personal use. The sale, trade, or commercialization of the crop is strictly prohibited.</li>
                      <li>Any breach by the Member or Cultivating Member of these terms shall result in immediate termination of membership.</li>
                      <li>This Agreement may be amended as laws and regulations evolve.</li>
                      <li>The Member's crop must be collected within 14 days of notification.</li>
                    </ol>
                  </li>
                  <li><strong>BLOCKCHAIN RECORD</strong>
                    <ol>
                      <li>The Member's interest in a shared crop pool (stokvel) is allocated and tracked via a blockchain ledger, with individual ownership labeled and barcoded.</li>
                      <li>The Member does not own the land or physical space but retains rights to the crop through their blockchain interest.</li>
                    </ol>
                  </li>
                  <li><strong>PRIVACY AND DATA PROTECTION</strong>
                    <ol>
                      <li>The Club commits to protecting Members' personal information in accordance with its Privacy Policy.</li>
                      <li>Personal data will not be shared without the Member's consent, except where required by law or for service provision.</li>
                    </ol>
                  </li>
                  <li><strong>USE OF ONLINE PORTAL</strong>
                    <ol>
                      <li>The Member will use their portal credentials to manage membership and services.</li>
                      <li>The Club reserves the right to suspend or terminate access for any breach of this Agreement.</li>
                    </ol>
                  </li>
                  <li><strong>TERM AND RENEWAL</strong>
                    <ol>
                      <li>This Agreement is valid for two (2) years from the date of signature.</li>
                      <li>It may be renewed for one (1) additional year upon two (2) months' prior written notice before expiry.</li>
                    </ol>
                  </li>
                  <li><strong>FEES AND PAYMENT</strong>
                    <ol>
                      <li>Membership Fees are payable in advance via POS, EFT, or card without deduction.</li>
                      <li>Delivery fees, if applicable, are charged separately.</li>
                    </ol>
                  </li>
                  <li><strong>WARRANTIES AND DISCLAIMERS</strong>
                    <ol>
                      <li>The Club does not guarantee specific levels of strength, potency, or concentration of Cannabis.</li>
                      <li>The Member indemnifies the Club, its employees, and agents against all claims arising from use, possession, or transport of Cannabis, or services rendered under this Agreement.</li>
                    </ol>
                  </li>
                  <li><strong>RELATIONSHIP OF THE PARTIES</strong>
                    <ol>
                      <li>The Club acts as an independent contractor and not as an agent, employee, or labor broker of the Member.</li>
                      <li>Neither Party may bind the other to obligations without written consent.</li>
                    </ol>
                  </li>
                  <li><strong>LIABILITY</strong>
                    <ol>
                      <li>Use of services is at the Member's sole risk.</li>
                      <li>The Club will not be liable for indirect, incidental, or consequential damages unless due to gross negligence or willful misconduct.</li>
                    </ol>
                  </li>
                  <li><strong>SHIPPING AND DELIVERY</strong>
                    <ol>
                      <li>Cannabis delivery by courier is available within South Africa, subject to separate fees.</li>
                      <li>The Club will notify Members of expected delivery dates and any delays.</li>
                      <li>Delivery is deemed complete upon delivery to the Member's nominated address.</li>
                      <li>Incorrect address details provided by the Member will result in additional courier fees, recoverable from the Member.</li>
                    </ol>
                  </li>
                  <li><strong>RETURNS AND REFUNDS</strong>
                    <ol>
                      <li>In the event of incorrect or poor-quality Cannabis delivery, the Member must notify the Club within four (4) days.</li>
                      <li>The Club will use its best efforts to resolve the issue at no additional charge.</li>
                    </ol>
                  </li>
                  <li><strong>GENERAL TERMS</strong>
                    <ol>
                      <li>Membership is personal and non-transferable.</li>
                      <li>The Member remains liable for outstanding fees up to the date of cancellation.</li>
                      <li>The Club may supplement shortfalls in crop allocation at its discretion.</li>
                      <li>The Club reserves the right to amend this Agreement, with notice to the Member via email. Continued use of services constitutes acceptance.</li>
                    </ol>
                  </li>
                  <li><strong>CONFIDENTIALITY</strong>
                    <ol>
                      <li>The Cultivating Member shall maintain strict confidentiality regarding the Member's identity, leased blockchain location, and grow records, during and after the membership term.</li>
                      <li>Circumvention by the Cultivating Member will result in liquidated damages of R100,000.00 payable to the Club.</li>
                    </ol>
                  </li>
                  <li><strong>TERMINATION</strong>
                    <ol>
                      <li>Either Party may terminate this Agreement with written notice for material breach.</li>
                      <li>The Member remains liable for any accrued fees and obligations up to the date of termination.</li>
                    </ol>
                  </li>
                </ol>
                <hr>
                <h3>SIGNATURES</h3>
                <p>
                  Signed at Route420WP on the {new Date().toLocaleDateString('en-ZA', { day: 'numeric', month: 'long', year: 'numeric' })}<br>
                  <br>
                  
                  <strong>For the Member:</strong><br>
                  Name: {firstName} {lastName}<br>
                  Signature:<br>
                  {#if signatureDataUrl}
                    <div class="no-break">
                      <img src={signatureDataUrl} alt="Signature" style="width:200px;"/>
                    </div>
                  {/if}
                  <br>
                  ID/Driver's License:<br>
                  {#if idImagePreview}
                    <div class="no-break">
                      <img src={idImagePreview} alt="ID" style="width:400px; margin-top: 8px;"/>
                    </div>
                  {/if}
                  <br>
                </p>
              </div>
            </div>
          </div>

          <button type="submit" class="submit-btn" disabled={loading}>
            {#if loading}
              <span class="loading-spinner"></span>
              Creating Account...
            {:else}
              Create Account
            {/if}
          </button>
        </form>

        <p class="auth-footer">
          Already have an account? <button type="button" class="link-btn" on:click={() => goto('/login')}>Sign in</button>
        </p>
      {/if}
    </div>
  </div>

  {#if showCameraModal}
    <div class="modal-backdrop" role="button" tabindex="0" aria-label="Close camera modal" on:click={stopCamera} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') stopCamera(); }}></div>
    <div class="modal camera-modal" role="dialog" aria-modal="true">
      <button class="close-btn" on:click={stopCamera} aria-label="Close camera">×</button>
      <div class="camera-container">
        <video
          bind:this={videoElement}
          autoplay
          playsinline
          muted
          class="camera-preview"
        ></video>
        {#if isCameraReady}
          <button type="button" class="capture-btn" on:click={capturePhoto}>
            Take Photo
          </button>
        {:else}
          <div class="camera-loading">Initializing camera...</div>
        {/if}
      </div>
    </div>
  {/if}

  <style>
    html, body {
      overflow-x: hidden;
      max-width: 100vw;
    }

    body {
      width: 100vw;
      box-sizing: border-box;
    }

    .auth-container {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      
      position: relative;
      z-index: 1;
      max-width: 100vw;
      box-sizing: border-box;
      overflow-x: hidden;
    }

    .auth-card {
      backdrop-filter: blur(10px);
     
      border-radius: 16px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
      max-width: 400px;
      width: 100%;
      border: 1px solid rgba(255, 255, 255, 0.2);
      box-sizing: border-box;
      overflow-x: hidden;
    }

    .logo {
      width: 120px;
      height: auto;
      margin: 0 auto 2rem;
      display: block;
      max-width: 100%;
    }

    h1, .subtitle, .auth-footer, label, .form-group, .agreement-content {
      max-width: 100%;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .form-group {
      margin-bottom: 1.5rem;
      text-align: center;
      max-width: 100%;
      box-sizing: border-box;
    }

    label {
      display: block;
      margin-bottom: 0.5rem;
      color: #e0e0e0;
      font-weight: 500;
      max-width: 100%;
      box-sizing: border-box;
    }

    input, button, .submit-btn, .link-btn {
      max-width: 100%;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    input {
      width: 100%;
      border: 1px solid rgba(0, 0, 0, 0.1);
      border-radius: 8px;
      font-size: 1rem;
      transition: all 0.2s;
      background: rgba(255, 255, 255, 0.9);
      text-align: center;
      box-sizing: border-box;
    }

    .password-hint {
      display: block;
      margin-top: 0.5rem;
      color: #666;
      font-size: 0.875rem;
      max-width: 100%;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .submit-btn {
      width: 100%;
      padding: 0.75rem;
      background: linear-gradient(135deg, #2196f3, #1976d2);
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.5rem;
      box-sizing: border-box;
      max-width: 100%;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .submit-btn:hover:not(:disabled) {
      background: linear-gradient(135deg, #1976d2, #1565c0);
      transform: translateY(-1px);
      box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
    }

    .submit-btn:disabled {
      background: #e0e0e0;
      cursor: not-allowed;
    }

    .error, .success {
      max-width: 100%;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .error {
      background: rgba(248, 215, 218, 0.9);
      color: #721c24;
      padding: 1rem;
      border-radius: 8px;
      margin-bottom: 1.5rem;
      text-align: center;
      backdrop-filter: blur(4px);
    }

    .success {
      background: rgba(212, 237, 218, 0.9);
      color: #155724;
      padding: 1rem;
      border-radius: 8px;
      margin-bottom: 1.5rem;
      text-align: center;
      backdrop-filter: blur(4px);
    }

    .auth-footer {
      text-align: center;
      margin-top: 1.5rem;
      color: #666;
      max-width: 100%;
      box-sizing: border-box;
    }

    .link-btn {
      background: none;
      border: none;
      color: #2196f3;
      text-decoration: underline;
      font-weight: 500;
      cursor: pointer;
      padding: 0;
      font: inherit;
      max-width: 100%;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .link-btn:hover {
      text-decoration: none;
    }

    .loading-spinner {
      width: 20px;
      height: 20px;
      border: 2px solid #ffffff;
      border-radius: 50%;
      border-top-color: transparent;
      animation: spin 0.8s linear infinite;
    }

    @keyframes spin {
      to {
        transform: rotate(360deg);
      }
    }

    @media (max-width: 480px) {
      .auth-container {
        padding: 1rem;
      }
      .auth-card {
       
        max-width: 100vw;
        width: 100vw;
      }
      h1 {
        font-size: 1.75rem;
      }
    }

    .upload-area {
      border: 2px dashed #dee2e6;
      border-radius: 6px;
      padding: 2rem;
      text-align: center;
      background: #f8f9fa;
      transition: all 0.2s;
      max-width: 100%;
      box-sizing: border-box;
      overflow-x: hidden;
    }

    .upload-area.active {
      border-color: #007bff;
      background: #e7f5ff;
    }

    .upload-label {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 0.5rem;
      cursor: pointer;
      max-width: 100%;
      box-sizing: border-box;
    }

    .upload-icon {
      font-size: 2rem;
    }

    .upload-hint {
      font-size: 0.875rem;
      color: #6c757d;
      max-width: 100%;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .file-input {
      display: none;
    }

    .preview-container {
      position: relative;
      display: inline-block;
      max-width: 100%;
      box-sizing: border-box;
    }

    .preview-image {
      max-width: 100%;
      max-height: 200px;
      border-radius: 4px;
      height: auto;
      box-sizing: border-box;
    }

    .remove-btn {
      position: absolute;
      top: -0.5rem;
      right: -0.5rem;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      background: #dc3545;
      color: white;
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1rem;
    }

    .signature-container {
      border: 1px solid #dee2e6;
      border-radius: 6px;
     
      background: white;
      box-sizing: border-box;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 320px;
      max-width: 100vw;
      aspect-ratio: 4/2;
      will-change: transform;
      contain: paint;
      margin: 0 auto;
    }

    .upload-options {
      display: flex;
      gap: 1rem;
      justify-content: center;
      flex-wrap: wrap;
      max-width: 100%;
      box-sizing: border-box;
    }

    .upload-label, .camera-btn {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 0.5rem;
      padding: 1rem;
      border: 1px solid #dee2e6;
      border-radius: 6px;
      background: white;
      cursor: pointer;
      transition: all 0.2s;
      min-width: 120px;
      max-width: 100%;
      box-sizing: border-box;
    }

    .upload-label:hover, .camera-btn:hover {
      border-color: #007bff;
      background: #f8f9fa;
    }

    .camera-loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-size: 1.2rem;
      text-align: center;
      background: rgba(0, 0, 0, 0.7);
      padding: 1rem 2rem;
      border-radius: 8px;
      max-width: 90vw;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .camera-modal {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: #000;
      padding: 1rem;
      border-radius: 12px;
      z-index: 2001;
      width: 95vw;
      max-width: 420px;
      box-sizing: border-box;
      overflow-x: hidden;
    }

    .camera-container {
      position: relative;
      width: 100%;
      aspect-ratio: 4/3;
      background: #000;
      border-radius: 8px;
      overflow: hidden;
      will-change: transform;
      contain: paint;
      margin: 0 auto;
    }

    .camera-preview {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      object-fit: cover;
      border-radius: 8px;
      transform: scaleX(-1);
      box-sizing: border-box;
      contain: paint;
    }

    .capture-btn {
      position: absolute;
      bottom: 1rem;
      left: 50%;
      transform: translateX(-50%);
      width: 64px;
      height: 64px;
      border-radius: 50%;
      background: white;
      border: 4px solid rgba(255, 255, 255, 0.3);
      cursor: pointer;
      transition: all 0.2s;
      z-index: 2;
      max-width: 100vw;
      box-sizing: border-box;
    }

    .capture-btn:hover {
      transform: translateX(-50%) scale(1.1);
    }

    .capture-btn::after {
      content: '';
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 48px;
      height: 48px;
      border-radius: 50%;
      background: white;
    }

    .signature-hint {
      text-align: center;
      color: #6c757d;
      font-size: 0.875rem;
      margin-top: 0.5rem;
      max-width: 100%;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .agreement-content {
      max-height: 300px;
      overflow-y: auto;
      background: rgba(255,255,255,0.95);
      border: 1px solid #ccc;
      border-radius: 8px;
      padding: 1rem;
      margin-top: 1.5rem;
      color: #222;
      font-size: 0.95em;
      max-width: 100vw;
      box-sizing: border-box;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    /* Responsive images, signature, and ID preview in contract */
    #contract-template img {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 0 auto;
      box-sizing: border-box;
    }

    /* Responsive signature pad and canvas */
    .signature-container canvas,
    .signature-container > canvas,
    .signature-pad canvas {
      width: 100% !important;
      height: 100% !important;
      max-width: 100%;
      max-height: 100%;
      display: block;
      box-sizing: border-box;
      background: #fff;
      border-radius: 4px;
      contain: paint;
    }

    /* Prevent horizontal scroll for all direct children */
    .auth-card > *,
    .auth-container > * {
      box-sizing: border-box;
      overflow-x: hidden;
    }

    /* Prevent horizontal scroll for html2pdf.js output */
    #contract-template {
      max-width: 100vw;
      box-sizing: border-box;
      overflow-x: auto;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    @media (max-width: 400px) {
      .signature-container {
        width: 95vw;
        min-width: 0;
      }
    }

    .no-break, #contract-template img {
      page-break-inside: avoid;
      break-inside: avoid;
      display: block;
    }
  </style>