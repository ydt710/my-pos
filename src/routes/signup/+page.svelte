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

        // Update the profile created by the trigger
        const { error: profileError } = await supabase
          .from('profiles')
          .update({
            // auth_user_id is the primary key and doesn't need to be updated
            email,
            display_name: displayName,
            phone_number: phoneNumber,
            signature_url: signatureUrl,
            id_image_url: idImageUrl,
            first_name: firstName,
            last_name: lastName,
            signed_contract_url: contractFilePath
          })
          .eq('auth_user_id', authData.user.id);

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
      
      // Wait a bit for reactive updates to complete
      await new Promise(resolve => setTimeout(resolve, 100));
      
      const element = document.getElementById('contract-template');
      if (!element) {
        console.error('Contract template not found');
        return null;
      }

      try {
        const opt = {
          margin: [0.75, 0.5, 0.75, 0.5], // top, right, bottom, left
          filename: 'contract.pdf',
          image: { type: 'jpeg', quality: 0.98 },
          html2canvas: { 
            scale: 2,
            useCORS: true,
            allowTaint: true,
            logging: false,
            backgroundColor: '#FFFFFF',
            letterRendering: true,
            onclone: (document: Document) => {
              const contractEl = document.getElementById('contract-template');
              if (contractEl) {
                // Force white background and black text
                contractEl.style.backgroundColor = 'white';
                contractEl.style.color = 'black';
                contractEl.style.padding = '20px';
                
                // Apply black color to all elements
                const allElements = contractEl.querySelectorAll('*');
                allElements.forEach((el: any) => {
                  // Preserve images
                  if (el.tagName !== 'IMG') {
                    el.style.color = 'black';
                  }
                });
                
                // Add page break CSS to prevent cutting
                const style = document.createElement('style');
                style.innerHTML = `
                  li, p { page-break-inside: avoid; }
                  ol, ul { page-break-inside: avoid; }
                  h1, h2, h3, h4, h5, h6 { page-break-after: avoid; }
                  .no-break { page-break-inside: avoid; }
                `;
                contractEl.appendChild(style);
              }
            }
          },
          jsPDF: { unit: 'in', format: 'a4', orientation: 'portrait' },
          pagebreak: { 
            mode: ['avoid-all', 'css', 'legacy'],
            before: '.page-break',
            after: '.page-break',
            avoid: ['li', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', '.no-break']
          }
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
      } catch (error) {
        console.error('Error generating PDF:', error);
        return null;
      }
    }
  </script>
  
  <StarryBackground />
  
  <div class="auth-container">
    <div class="auth-card glass">
      {#if logoUrl}
        <div class="logo-container">
          <img src={logoUrl} alt="Logo" class="logo" />
        </div>
      {/if}
      
      <div class="auth-header">
        <h1 class="neon-text-cyan">Create Account</h1>
        <p class="neon-text-white auth-subtitle">Join us today</p>
      </div>

      {#if signedContractDownloadUrl}
        <div class="success-container glass-light" transition:fade>
          <div class="success-content">
            <div class="success-icon">✅</div>
            <h2 class="neon-text-green">Account created successfully!</h2>
            <p class="neon-text-white">Your contract is ready for download.</p>
            <button type="button" class="btn btn-success btn-large" on:click={handleDownloadClick}>
              <span class="btn-icon">📄</span>
              Download Signed Contract
            </button>
            <button type="button" class="btn btn-secondary" on:click={() => goto('/')} style="margin-top: 1rem;">
              <span class="btn-icon">🏠</span>
              Go to Home
            </button>
          </div>
        </div>
      {:else if success}
        <div class="success-container glass-light" transition:fade>
          <div class="success-content">
            <div class="success-icon">🎉</div>
            <h2 class="neon-text-green">{success}</h2>
            <p class="neon-text-white">Redirecting to home...</p>
          </div>
        </div>
      {:else}
        <form on:submit|preventDefault={signup} class="auth-form">
          <!-- Personal Information Section -->
          <div class="form-section">
            <h3 class="section-title neon-text-white">
              <span class="section-icon">👤</span>
              Personal Information
            </h3>
            
            <div class="form-row">
              <div class="form-group">
                <label for="firstName" class="form-label neon-text-white">
                  <span class="label-icon">📝</span>
                  First Name
                </label>
                <input
                  id="firstName"
                  type="text"
                  bind:value={firstName}
                  placeholder="Enter your first name"
                  required
                  class="form-control neon-input"
                />
              </div>

              <div class="form-group">
                <label for="lastName" class="form-label neon-text-white">
                  <span class="label-icon">📝</span>
                  Last Name
                </label>
                <input
                  id="lastName"
                  type="text"
                  bind:value={lastName}
                  placeholder="Enter your last name"
                  required
                  class="form-control neon-input"
                />
              </div>
            </div>

            <div class="form-group">
              <label for="displayName" class="form-label neon-text-white">
                <span class="label-icon">🏷️</span>
                Display Name
              </label>
              <input
                id="displayName"
                type="text"
                bind:value={displayName}
                placeholder="Enter your display name"
                required
                class="form-control neon-input"
              />
            </div>

            <div class="form-group">
              <label for="phoneNumber" class="form-label neon-text-white">
                <span class="label-icon">📱</span>
                Phone Number
              </label>
              <input
                id="phoneNumber"
                type="tel"
                bind:value={phoneNumber}
                placeholder="Enter your phone number"
                required
                class="form-control neon-input"
              />
            </div>
          </div>

          <!-- Account Credentials Section -->
          <div class="form-section">
            <h3 class="section-title neon-text-white">
              <span class="section-icon">🔐</span>
              Account Credentials
            </h3>

            <div class="form-group">
              <label for="email" class="form-label neon-text-white">
                <span class="label-icon">📧</span>
                Email Address
              </label>
              <input
                id="email"
                type="email"
                bind:value={email}
                placeholder="Enter your email"
                required
                autocomplete="username"
                class="form-control neon-input"
              />
            </div>

            <div class="form-group">
              <label for="password" class="form-label neon-text-white">
                <span class="label-icon">🔒</span>
                Password
              </label>
              <input
                id="password"
                type="password"
                bind:value={password}
                placeholder="Create a password"
                required
                autocomplete="new-password"
                minlength="6"
                class="form-control neon-input"
              />
              <small class="form-hint">Password must be at least 6 characters long</small>
            </div>
          </div>

          <!-- Digital Signature Section -->
          <div class="form-section">
            <h3 class="section-title neon-text-white">
              <span class="section-icon">✍️</span>
              Digital Signature
            </h3>
            
            <div class="form-group">
              <label for="signature-pad" class="form-label neon-text-white">Signature</label>
              <div class="signature-container glass-light" id="signature-pad">
                <SignaturePad
                  bind:this={signaturePad}
                  width={320}
                  height={160}
                  on:change={debouncedSignatureChange}
                />
                {#if isSignatureEmpty}
                  <div class="signature-hint neon-text-secondary">Please sign above</div>
                {/if}
              </div>
            </div>
          </div>

          <!-- ID Verification Section -->
          <div class="form-section">
            <h3 class="section-title neon-text-white">
              <span class="section-icon">🆔</span>
              ID Verification
            </h3>
            
            <div class="form-group">
              <label for="idImage" class="form-label neon-text-white">ID/Driver's License</label>
              <div class="upload-area glass-light" class:active={isCapturingId}>
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
                    <label for="idImage" class="upload-option">
                      <div class="upload-icon">📁</div>
                      <span class="neon-text-white">Upload File</span>
                      <span class="upload-hint neon-text-secondary">PNG, JPG up to 5MB</span>
                      <input
                        type="file"
                        id="idImage"
                        accept="image/*"
                        on:change={handleIdImageCapture}
                        class="file-input"
                      />
                    </label>
                    <button type="button" class="upload-option camera-btn" on:click={startCamera}>
                      <div class="upload-icon">📷</div>
                      <span class="neon-text-white">Take Photo</span>
                    </button>
                  </div>
                {/if}
              </div>
            </div>
          </div>

          <!-- Agreement Section -->
          <div class="form-section">
            <h3 class="section-title neon-text-white">
              <span class="section-icon">📋</span>
              Membership Agreement Preview
            </h3>
            
            <div class="agreement-content glass-light">
              <div id="contract-template" style="background-color: white; color: black;">
                <h2 style="text-align:center; color: black;">MEMBERSHIP AGREEMENT</h2>
                <p style="color: black;"><strong style="color: black;">Between:</strong><br>
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

          <button type="submit" class="btn btn-primary btn-large" disabled={loading}>
            {#if loading}
              <span class="loading-spinner"></span>
              Creating Account...
            {:else}
              <span class="btn-icon">🚀</span>
              Create Account
            {/if}
          </button>
        </form>

        <div class="auth-footer">
          <p class="neon-text-secondary">
            Already have an account? 
            <button type="button" class="link-btn neon-text-cyan" on:click={() => goto('/login')}>
              Sign in
            </button>
          </p>
        </div>
      {/if}
    </div>
  </div>

  {#if showCameraModal}
    <div class="modal-backdrop" role="button" tabindex="0" aria-label="Close camera modal" on:click={stopCamera} on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') stopCamera(); }}></div>
    <div class="camera-modal glass" role="dialog" aria-modal="true">
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
          <div class="camera-loading neon-text-white">Initializing camera...</div>
        {/if}
      </div>
    </div>
  {/if}

  <style>
    .auth-container {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 2rem;
      position: relative;
      z-index: 1;
    }

    .auth-card {
      max-width: 800px;
      width: 100%;
      padding: 2.5rem;
      backdrop-filter: blur(20px);
      border: 1px solid var(--border-neon);
      box-shadow: var(--shadow-neon), 0 8px 32px rgba(0, 242, 254, 0.1);
      position: relative;
      overflow: hidden;
    }

    .auth-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 2px;
      background: var(--gradient-primary);
      opacity: 0.8;
    }

    .logo-container {
      text-align: center;
      margin-bottom: 2rem;
    }

    .logo {
      width: 120px;
      height: auto;
      filter: drop-shadow(0 0 10px rgba(0, 242, 254, 0.3));
      transition: all 0.3s ease;
    }

    .logo:hover {
      filter: drop-shadow(0 0 20px rgba(0, 242, 254, 0.6));
      transform: scale(1.05);
    }

    .auth-header {
      text-align: center;
      margin-bottom: 2rem;
    }

    .auth-header h1 {
      font-size: 2.5rem;
      margin: 0 0 0.5rem;
      font-weight: 700;
      text-shadow: var(--text-shadow-neon);
      letter-spacing: 0.02em;
    }

    .auth-subtitle {
      font-size: 1.1rem;
      margin: 0;
      opacity: 0.9;
      letter-spacing: 0.01em;
    }

    .auth-form {
      margin-bottom: 2rem;
    }

    /* Form Sections */
    .form-section {
      margin-bottom: 2.5rem;
      padding: 1.5rem;
      background: rgba(13, 17, 23, 0.4);
      border: 1px solid rgba(0, 242, 254, 0.1);
      border-radius: 12px;
      backdrop-filter: blur(10px);
    }

    .section-title {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      margin-bottom: 1.5rem;
      font-size: 1.2rem;
      font-weight: 600;
      border-bottom: 1px solid rgba(0, 242, 254, 0.2);
      padding-bottom: 0.75rem;
    }

    .section-icon {
      font-size: 1.4rem;
      opacity: 0.9;
    }

    .form-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1rem;
    }

    .form-group {
      margin-bottom: 1.25rem;
    }

    .form-label {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      margin-bottom: 0.5rem;
      font-weight: 600;
      font-size: 0.95rem;
      letter-spacing: 0.01em;
    }

    .label-icon {
      font-size: 1.1rem;
      opacity: 0.8;
    }

    .neon-input {
      width: 100%;
      background: rgba(13, 17, 23, 0.8);
      border: 1px solid rgba(0, 242, 254, 0.3);
      color: var(--text-primary);
      font-size: 1rem;
      transition: all 0.3s ease;
      text-align: center;
    }

    .neon-input:focus {
      outline: none;
      border-color: var(--neon-cyan);
      box-shadow: 0 0 0 2px rgba(0, 242, 254, 0.2), inset 0 0 20px rgba(0, 242, 254, 0.05);
      background: rgba(0, 242, 254, 0.05);
    }

    .neon-input::placeholder {
      color: rgba(255, 255, 255, 0.5);
      font-style: italic;
    }

    .form-hint {
      display: block;
      margin-top: 0.5rem;
      color: rgba(255, 255, 255, 0.6);
      font-size: 0.875rem;
      font-style: italic;
    }

    /* Button Styles */
    .btn-large {
      width: 100%;
      padding: 0.875rem 1.5rem;
      font-size: 1.1rem;
      font-weight: 600;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.75rem;
      position: relative;
      overflow: hidden;
      margin-top: 1rem;
    }

    .btn-large::before {
      content: '';
      position: absolute;
      top: 0;
      left: -100%;
      width: 100%;
      height: 100%;
      background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.1), transparent);
      transition: left 0.5s;
    }

    .btn-large:hover::before {
      left: 100%;
    }

    .btn-icon {
      font-size: 1.2rem;
    }

    /* Success States */
    .success-container {
      text-align: center;
      padding: 2rem;
      border: 1px solid rgba(67, 233, 123, 0.3);
      border-radius: 12px;
      backdrop-filter: blur(10px);
    }

    .success-content {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 1rem;
    }

    .success-icon {
      font-size: 3rem;
      margin-bottom: 0.5rem;
    }

    .success-container h2 {
      margin: 0;
      font-size: 1.5rem;
      font-weight: 700;
    }

    .success-container p {
      margin: 0;
      opacity: 0.9;
    }

    .auth-footer {
      text-align: center;
      padding-top: 1.5rem;
      border-top: 1px solid rgba(0, 242, 254, 0.2);
    }

    .auth-footer p {
      margin: 0;
      font-size: 0.95rem;
    }

    .link-btn {
      background: none;
      border: none;
      font-weight: 600;
      cursor: pointer;
      padding: 0;
      font: inherit;
      text-decoration: none;
      transition: all 0.3s ease;
      position: relative;
    }

    .link-btn::after {
      content: '';
      position: absolute;
      bottom: -2px;
      left: 0;
      width: 0;
      height: 2px;
      background: var(--gradient-primary);
      transition: width 0.3s ease;
    }

    .link-btn:hover::after {
      width: 100%;
    }

    .link-btn:hover {
      text-shadow: 0 0 8px rgba(0, 242, 254, 0.6);
      transform: translateY(-1px);
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

    .loading-spinner {
      width: 20px;
      height: 20px;
      border: 2px solid rgba(255, 255, 255, 0.3);
      border-radius: 50%;
      border-top-color: #fff;
      animation: spin 0.8s linear infinite;
    }

    @keyframes spin {
      to {
        transform: rotate(360deg);
      }
    }

    /* Mobile Responsiveness */
    @media (max-width: 1024px) {
      .auth-card {
        max-width: 700px;
        padding: 2rem;
      }

      .form-section {
        padding: 1.25rem;
      }
    }

    @media (max-width: 768px) {
      .auth-container {
        padding: 1rem;
      }

      .auth-card {
        padding: 1.5rem;
        max-width: 100%;
      }

      .auth-header h1 {
        font-size: 2rem;
      }

      .form-row {
        grid-template-columns: 1fr;
        gap: 0;
      }

      .form-section {
        margin-bottom: 2rem;
        padding: 1rem;
      }

      .section-title {
        font-size: 1.1rem;
      }

      .upload-options {
        flex-direction: column;
        gap: 0.75rem;
      }

      .upload-option {
        min-width: auto;
        width: 100%;
      }

      .signature-container {
        max-width: 100%;
      }

      .logo {
        width: 100px;
      }
    }

    @media (max-width: 480px) {
      .auth-container {
        padding: 0.75rem;
      }

      .auth-card {
        padding: 1.25rem;
      }

      .auth-header h1 {
        font-size: 1.75rem;
      }

      .auth-subtitle {
        font-size: 1rem;
      }

      .form-section {
        padding: 0.75rem;
        margin-bottom: 1.5rem;
      }

      .section-title {
        font-size: 1rem;
        gap: 0.5rem;
      }

      .section-icon {
        font-size: 1.2rem;
      }

      .form-label {
        font-size: 0.9rem;
      }

      .neon-input {
        font-size: 0.95rem;
      }

      .btn-large {
        padding: 0.75rem 1.25rem;
        font-size: 1rem;
      }

      .logo {
        width: 80px;
      }

      .agreement-content {
        max-height: 250px;
        
        font-size: 0.85em;
      }

      .camera-modal {
        width: 98vw;
        max-width: none;
        padding: 1rem;
      }
    }

    /* Enhanced glow effects for premium feel */
    @media (min-width: 769px) {
      .auth-card:hover {
        box-shadow: var(--shadow-neon), 0 12px 40px rgba(0, 242, 254, 0.15);
        transform: translateY(-2px);
      }

      .neon-input:hover {
        border-color: rgba(0, 242, 254, 0.5);
      }

      .form-section:hover {
        border-color: rgba(0, 242, 254, 0.2);
        background: rgba(13, 17, 23, 0.5);
      }
    }

    /* Dark mode enhancements */
    @media (prefers-color-scheme: dark) {
      .neon-input {
        background: rgba(0, 0, 0, 0.6);
      }

      .agreement-content {
        background: rgba(255, 255, 255, 0.98);
      }
    }

    /* Upload Area Styles */
    .upload-area {
      border: 2px dashed rgba(0, 242, 254, 0.3);
      border-radius: 12px;
      padding: 2rem;
      text-align: center;
      transition: all 0.3s ease;
      background: rgba(13, 17, 23, 0.4);
      backdrop-filter: blur(10px);
    }

    .upload-area.active {
      border-color: var(--neon-cyan);
      background: rgba(0, 242, 254, 0.05);
      box-shadow: 0 0 20px rgba(0, 242, 254, 0.1);
    }

    .upload-options {
      display: flex;
      gap: 1rem;
      justify-content: center;
      flex-wrap: wrap;
    }

    .upload-option {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 0.5rem;
      padding: 1rem;
      border: 1px solid rgba(0, 242, 254, 0.3);
      border-radius: 8px;
      background: rgba(13, 17, 23, 0.6);
      cursor: pointer;
      transition: all 0.3s ease;
      min-width: 120px;
    }

    .upload-option:hover {
      border-color: var(--neon-cyan);
      background: rgba(0, 242, 254, 0.05);
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(0, 242, 254, 0.1);
    }

    .upload-icon {
      font-size: 2rem;
      opacity: 0.8;
    }

    .upload-hint {
      font-size: 0.875rem;
      opacity: 0.7;
      font-style: italic;
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

    /* Signature Pad Styles */
    .signature-container {
      border: 1px solid rgba(0, 242, 254, 0.3);
      border-radius: 12px;
      background: rgba(255, 255, 255, 0.95);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 100%;
      max-width: 400px;
      aspect-ratio: 4/2;
      margin: 0 auto;
      transition: all 0.3s ease;
      backdrop-filter: blur(5px);
    }

    .signature-container:hover {
      border-color: var(--neon-cyan);
      box-shadow: 0 0 15px rgba(0, 242, 254, 0.1);
    }

    .signature-hint {
      text-align: center;
      font-size: 0.875rem;
      margin-top: 0.5rem;
      font-style: italic;
      opacity: 0.7;
    }



    .camera-container {
      position: relative;
      width: 100%;
      aspect-ratio: 4/3;
      background: #000;
      border-radius: 12px;
      overflow: hidden;
      margin: 0 auto;
    }

    .camera-preview {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      object-fit: cover;
      border-radius: 12px;
      transform: scaleX(-1);
    }

    .capture-btn {
      position: absolute;
      bottom: 1rem;
      left: 50%;
      transform: translateX(-50%);
      width: 64px;
      height: 64px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.9);
      border: 4px solid rgba(0, 242, 254, 0.5);
      cursor: pointer;
      transition: all 0.3s ease;
      z-index: 2;
    }

    .capture-btn:hover {
      transform: translateX(-50%) scale(1.1);
      background: rgba(255, 255, 255, 1);
      border-color: var(--neon-cyan);
      box-shadow: 0 0 20px rgba(0, 242, 254, 0.3);
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
      background: rgba(0, 242, 254, 0.8);
    }

    .camera-loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      font-size: 1.2rem;
      text-align: center;
      background: rgba(0, 0, 0, 0.8);
      padding: 1rem 2rem;
      border-radius: 8px;
      backdrop-filter: blur(5px);
    }

    /* Camera Modal Styles */
    .modal-backdrop {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.8);
      backdrop-filter: blur(5px);
      z-index: 2000;
    }

    .camera-modal {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      padding: 1.5rem;
      border-radius: 16px;
      z-index: 2001;
      width: 95vw;
      max-width: 500px;
      border: 1px solid var(--border-neon);
      backdrop-filter: blur(20px);
      box-shadow: var(--shadow-neon), 0 8px 32px rgba(0, 242, 254, 0.2);
    }

    .close-btn {
      position: absolute;
      top: 1rem;
      right: 1rem;
      width: 32px;
      height: 32px;
      border: none;
      background: rgba(220, 53, 69, 0.8);
      color: white;
      border-radius: 50%;
      cursor: pointer;
      font-size: 1.2rem;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 2002;
      transition: all 0.3s ease;
    }

    .close-btn:hover {
      background: rgba(220, 53, 69, 1);
      transform: scale(1.1);
    }





    /* Agreement Content */
    .agreement-content {
      max-height: 400px;
      overflow-y: auto;
      background: rgba(255, 255, 255, 0.95);
      border: 1px solid rgba(0, 242, 254, 0.2);
      border-radius: 12px;
     
      color: #222;
      font-size: 0.9em;
      backdrop-filter: blur(5px);
      box-shadow: inset 0 2px 8px rgba(0, 0, 0, 0.05);
    }

    .agreement-content::-webkit-scrollbar {
      width: 6px;
    }

    .agreement-content::-webkit-scrollbar-track {
      background: rgba(0, 0, 0, 0.1);
      border-radius: 3px;
    }

    .agreement-content::-webkit-scrollbar-thumb {
      background: rgba(0, 242, 254, 0.3);
      border-radius: 3px;
    }

    .agreement-content::-webkit-scrollbar-thumb:hover {
      background: rgba(0, 242, 254, 0.5);
    }
    
    /* Ensure contract template has black text */
    #contract-template {
      color: black !important;
      background-color: white !important;
    }
    
    #contract-template * {
      color: black !important;
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
    
    /* Page break control for PDF generation */
    #contract-template li,
    #contract-template p,
    #contract-template ol > li {
      page-break-inside: avoid !important;
      break-inside: avoid !important;
    }
    
    #contract-template h1,
    #contract-template h2,
    #contract-template h3,
    #contract-template h4,
    #contract-template h5,
    #contract-template h6 {
      page-break-after: avoid !important;
      break-after: avoid !important;
    }
    
    #contract-template ol,
    #contract-template ul {
      page-break-inside: auto !important;
    }
    
    /* Keep numbered items together */
    #contract-template ol > li {
      orphans: 3;
      widows: 3;
    }
  </style>