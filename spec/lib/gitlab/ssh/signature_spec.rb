# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ssh::Signature, feature_category: :source_code_management do
  # ssh-keygen -t ed25519
  let_it_be(:committer_email) { 'ssh-commit-test@example.com' }
  let_it_be(:public_key_text) { 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHZ8NHEnCIpC4mnot+BRxv6L+fq+TnN1CgsRrHWLmfwb' }
  let_it_be_with_reload(:user) { create(:user, email: committer_email) }
  let_it_be_with_reload(:key) { create(:key, usage_type: :signing, key: public_key_text, user: user) }

  let(:signed_text) { 'This message was signed by an ssh key' }
  let(:signer) { :SIGNER_USER }

  let(:signature_text) do
    # ssh-keygen -Y sign -n git -f id_test message.txt
    <<~SIG
      -----BEGIN SSH SIGNATURE-----
      U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAgdnw0cScIikLiaei34FHG/ov5+r
      5Oc3UKCxGsdYuZ/BsAAAADZ2l0AAAAAAAAAAZzaGE1MTIAAABTAAAAC3NzaC1lZDI1NTE5
      AAAAQDWOEauf0jXyA9caa5bOgK5QZD6c69pm+EbG3GMw5QBL3N/Gt+r413McCSJFohWWBk
      Lxemg8NzZ0nB7lTFbaxQc=
      -----END SSH SIGNATURE-----
    SIG
  end

  subject(:signature) do
    described_class.new(
      signature_text,
      signed_text,
      signer,
      committer_email
    )
  end

  shared_examples 'verified signature' do
    it 'reports verified status' do
      expect(signature.verification_status).to eq(:verified)
    end
  end

  shared_examples 'unverified signature' do
    it 'reports unverified status' do
      expect(signature.verification_status).to eq(:unverified)
    end
  end

  describe 'signature verification' do
    context 'when signature is valid and user email is verified' do
      it_behaves_like 'verified signature'
    end

    context 'when using an RSA key' do
      let(:public_key_text) do
        <<~KEY.delete("\n")
          ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDkq6ko8LMxf2NwyJKh+77KSDc7/ynPgUJD
          IopkhqftuHFYe2Y+V3MBJnpzfSRwR2xGfXQUUzLU9AGyfZIO/ZLK2yvfhlO3k//5PbAaZb3y
          urlnF9T1d2nhtfi8wuzsEn7Boh6qdoWPFIsloAL/X0PXH1HWKmzyNer92HKGrnWFfaaEMo0n
          T3ureAhRG4IONyUcOK+DyoH+YbxXSlHnLO2oHHlWaP9RrJCHbfAQbfDhaZCI0cNkXXOwUwA4
          yWGzDibfXZTvaYxpjbz1xoHmCAq8IrobCgkQaEg3PH3vPGnbP0TpViXjMnZyBZyT7tg9WHBV
          kAsl0CizyUgZHPAPYuqKy5JNlnjVjeqYeIgdN4Tj7hpJ1n0hVpRk4zQNYRmAAj3GNqgPAsd0
          3i4rW8cqmhO0fmhP5DgQ7Mt5S9AgcTcCr6niPacK34XrwKiRjxXmCLjr36q8wuRU3QdMt+MK
          Zxk/qJdAUIltz+nuGiwct0w+sWefYzmiRXu6hljBBrRAvnU=
        KEY
      end

      let(:signature_text) do
        <<~SIG
          -----BEGIN SSH SIGNATURE-----
          U1NIU0lHAAAAAQAAAZcAAAAHc3NoLXJzYQAAAAMBAAEAAAGBAOSrqSjwszF/Y3DIkqH7vs
          pINzv/Kc+BQkMiimSGp+24cVh7Zj5XcwEmenN9JHBHbEZ9dBRTMtT0AbJ9kg79ksrbK9+G
          U7eT//k9sBplvfK6uWcX1PV3aeG1+LzC7OwSfsGiHqp2hY8UiyWgAv9fQ9cfUdYqbPI16v
          3YcoaudYV9poQyjSdPe6t4CFEbgg43JRw4r4PKgf5hvFdKUecs7agceVZo/1GskIdt8BBt
          8OFpkIjRw2Rdc7BTADjJYbMOJt9dlO9pjGmNvPXGgeYICrwiuhsKCRBoSDc8fe88ads/RO
          lWJeMydnIFnJPu2D1YcFWQCyXQKLPJSBkc8A9i6orLkk2WeNWN6ph4iB03hOPuGknWfSFW
          lGTjNA1hGYACPcY2qA8Cx3TeLitbxyqaE7R+aE/kOBDsy3lL0CBxNwKvqeI9pwrfhevAqJ
          GPFeYIuOvfqrzC5FTdB0y34wpnGT+ol0BQiW3P6e4aLBy3TD6xZ59jOaJFe7qGWMEGtEC+
          dQAAAANnaXQAAAAAAAAABnNoYTUxMgAAAZQAAAAMcnNhLXNoYTItNTEyAAABgEnuYyYOlM
          CSR+wvmBY7eKHzFor5ByM7N4F7VZAGKK/vbS3C38xDdiJZwsZUscpe5WspJVCWUTkFxXjn
          GW7vseIfJBVkyqnu2uN8X1j/VDLFESEajcchPhPxtfAMK1/NL99O7rCrYX2pmpkm9tWsFk
          NX5B93sRyDUnHAOkB+zdqU8P0xdzc8kmBl5OOqu1rSjZIgnQjcauEIRIUN+rFuiRRmIvJp
          UvMhkKSsRCH93btGW7A6x5e4iPzP+Em0UFYJdOx2lvu9aVAktQzysGwDN+9c4IC+07UHKT
          UIE5jSbR1QKfavcywNQnCltQ2bTxpnm4A6QHKcdr9Q57dV014FgtmtT/Pw03iyl5MwbEqW
          7YEHSkMyAcd1rjEpOCN2pJjjbrOKLePG0R2ffgvVJnTWGFklCxsJ1/7IASHst1wg1/gu1g
          Kx/TEv+gOKpehAgs2Sz/4kZtFuHO2dbHYC3UrPR5HT8JnQWeCfiT0qwsVQ6xribw0jEYyd
          ZBNWKkPdNocAbA==
          -----END SSH SIGNATURE-----
        SIG
      end

      before do
        key.update!(key: public_key_text)
      end

      it_behaves_like 'verified signature'
    end

    context 'when signed text is an empty string' do
      let(:signed_text) { '' }
      let(:signature_text) do
        <<~SIG
          -----BEGIN SSH SIGNATURE-----
          U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAgdnw0cScIikLiaei34FHG/ov5+r
          5Oc3UKCxGsdYuZ/BsAAAADZ2l0AAAAAAAAAAZzaGE1MTIAAABTAAAAC3NzaC1lZDI1NTE5
          AAAAQP2liwaQ44PC9oXf5Xzjq20WLdWEK9nyonvDGtduGUXMOL4yP5A6WvKz7kSt7Vba/U
          MNK0nmnNc7Aokfh/2eRQE=
          -----END SSH SIGNATURE-----
        SIG
      end

      it_behaves_like 'verified signature'
    end

    context 'when signed text is nil' do
      let(:signed_text) { nil }
      let(:signature_text) do
        <<~SIG
          -----BEGIN SSH SIGNATURE-----
          U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAgko5+o4fR8N175Rr/VI5uRcHUIQ
          MXkzpR8BEylbcXzu4AAAAEZmlsZQAAAAAAAAAGc2hhNTEyAAAAUwAAAAtzc2gtZWQyNTUx
          OQAAAEC1y2I7o3KqKFlnM+MLkhIo+uRX3YQOYCqycfibyfvmkZTcwqMxgNBInBM9pY3VvS
          sbW2iEdgz34agHbi+1BHIM
          -----END SSH SIGNATURE-----
        SIG
      end

      it_behaves_like 'unverified signature'
    end

    context 'when committer_email is empty' do
      let(:committer_email) { '' }

      it_behaves_like 'unverified signature'
    end

    context 'when committer_email is nil' do
      let(:committer_email) { nil }

      it_behaves_like 'unverified signature'
    end

    context 'when signature_text is empty' do
      let(:signature_text) { '' }

      it_behaves_like 'unverified signature'
    end

    context 'when signature_text is nil' do
      let(:signature_text) { nil }

      it_behaves_like 'unverified signature'
    end

    context 'when user email is not verified' do
      before do
        email = user.emails.find_by(email: committer_email)
        email.update!(confirmed_at: nil)
        user.update!(confirmed_at: nil)
      end

      it 'reports unverified status' do
        expect(signature.verification_status).to eq(:unverified)
      end
    end

    context 'when no user exist with the committer email' do
      before do
        user.delete
      end

      it 'reports other_user status' do
        expect(signature.verification_status).to eq(:other_user)
      end
    end

    context 'when no user exists with the committer email' do
      let(:committer_email) { 'different-email+ssh-commit-test@example.com' }

      it 'reports other_user status' do
        expect(signature.verification_status).to eq(:other_user)
      end
    end

    context 'when signature is invalid' do
      let(:signature_text) do
        # truncated base64
        <<~SIG
          -----BEGIN SSH SIGNATURE-----
          U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAgko5+o4fR8N175Rr/VI5uRcHUIQ
          MXkzpR8BEylbcXzu4AAAAEZmlsZQAAAAAAAAAGc2hhNTEyAAAAUwAAAAtzc2gtZWQyNTUx
          OQAAAECQa95KgBkgbMwIPNwHRjHu0WYrKvAc5O/FaBXlTDcPWQHi8WRDhbPNN6MqSYLg/S
          -----END SSH SIGNATURE-----
        SIG
      end

      it_behaves_like 'unverified signature'
    end

    context 'when signature is for a different namespace' do
      let(:signature_text) do
        <<~SIG
          -----BEGIN SSH SIGNATURE-----
          U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAgdnw0cScIikLiaei34FHG/ov5+r
          5Oc3UKCxGsdYuZ/BsAAAAEZmlsZQAAAAAAAAAGc2hhNTEyAAAAUwAAAAtzc2gtZWQyNTUx
          OQAAAEAd6Psg4D/5IdSVTy35D4t2iNX4udJnX8JrUCjQl0GoPl1vzPjgyvxdzdoQl6bh1w
          4rror3RuzUYBGzIioIc1MP
          -----END SSH SIGNATURE-----
        SIG
      end

      it_behaves_like 'unverified signature'
    end

    context 'when signature is for a different message' do
      let(:signature_text) do
        <<~SIG
          -----BEGIN SSH SIGNATURE-----
          U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAgQtog20+l2pMcPnuoaWXuNpw9u7
          OzPnJzdLUon0+ELNQAAAAEZmlsZQAAAAAAAAAGc2hhNTEyAAAAUwAAAAtzc2gtZWQyNTUx
          OQAAAEB3/B+6c3+XqEuqjiqlVQwQmUdj8WquROtkhdtScEOP8GXcGQx+aaQs5nq4ZJCuu5
          ywcU+4xQaLVpCf7tfGWa4K
          -----END SSH SIGNATURE-----
        SIG
      end

      it_behaves_like 'unverified signature'
    end

    context 'when message has been tampered' do
      let(:signed_text) do
        <<~MSG
          This message was signed by an ssh key
          The pubkey fingerprint is SHA256:RjzeOilYHkiHqz5fefdnrWr8qn5nbroAisuuTMoH9PU
        MSG
      end

      it_behaves_like 'unverified signature'
    end

    context 'when the signing key does not exist in GitLab' do
      context 'when the key is not a signing one' do
        before do
          key.auth!
        end

        it 'reports unknown_key status' do
          expect(signature.verification_status).to eq(:unknown_key)
        end
      end

      context 'when the key is removed' do
        before do
          key.delete
        end

        it 'reports unknown_key status' do
          expect(signature.verification_status).to eq(:unknown_key)
        end
      end
    end

    context 'when key belongs to someone other than the committer' do
      let_it_be(:other_user) { create(:user, email: 'other-user@example.com') }

      let(:committer_email) { other_user.email }

      it 'reports other_user status' do
        expect(signature.verification_status).to eq(:other_user)
      end
    end

    context 'when signature created by GitLab' do
      let(:signer) { :SIGNER_SYSTEM }

      it 'reports verified_system status' do
        expect(signature.verification_status).to eq(:verified_system)
        expect(signature.key_fingerprint).to eq('dw7gPSvYtkCBU+BbTolbbckUEX3sL6NsGIJTQ4PYEnM')
      end
    end
  end

  describe '#key_fingerprint' do
    it 'returns the pubkey sha256 fingerprint' do
      expect(signature.key_fingerprint).to eq('dw7gPSvYtkCBU+BbTolbbckUEX3sL6NsGIJTQ4PYEnM')
    end

    context 'when a signature has been created with a certificate' do
      let(:signature_text) do
        # ssh-keygen -Y sign -n git -f id_test-cert.pub message.txt
        <<~SIG
          -----BEGIN SSH SIGNATURE-----
          U1NIU0lHAAAAAQAABGIAAAAgc3NoLWVkMjU1MTktY2VydC12MDFAb3BlbnNzaC5jb20AAA
          Aga68FsjVAge+7I5h/qC8luu7iK+5QfrVlDnKRVy1d7zUAAAAgYAsBVqgfGrvGdSPjqY0H
          t8yljpOS4VumZHnAh+wCvdEAAAAAAAAAAAAAAAEAAAARYWRtaW5AZXhhbXBsZS5jb20AAA
          AAAAAAAGV8UoAAAAAAZX2kUQAAAAAAAACCAAAAFXBlcm1pdC1YMTEtZm9yd2FyZGluZwAA
          AAAAAAAXcGVybWl0LWFnZW50LWZvcndhcmRpbmcAAAAAAAAAFnBlcm1pdC1wb3J0LWZvcn
          dhcmRpbmcAAAAAAAAACnBlcm1pdC1wdHkAAAAAAAAADnBlcm1pdC11c2VyLXJjAAAAAAAA
          AAAAAAGXAAAAB3NzaC1yc2EAAAADAQABAAABgQDWpZvEFL60+ijqjg/UGEWnjnHsxzEDZe
          L00prZ7XdZE9yQXb2eI5TmPP/NRXHL4gRuaVBvwllOEeZRI7TJtMCVGQhw8ORVc7sYb6Pp
          Y4j1AI35SsdM9SrNLucPtR8k46ab4vT0cuT/jx8fEppF7bjJ86NOfVUxGv5mhYv21iIX6L
          XRUpBlLOGlxtU83PgP8Z5f4T6WUkcLM+Uh22msk15EAnWPF3FQbTH1VA88dHJG76gnpaD2
          0FJffhaLYl9UJAzDBZqjYeqjNuVN3+BOzi3zAZNhaPXOznw2QXHMXWmgOao4hLWgk5wgUa
          vXkQehqtB0kQhn8xXir8RbEzPDBToxVWnMJKVO27MtovjWUorNKRFlySwafKKuem/lBulU
          2VcUvSbB4mRSdZZimqmTieSO8s0onq3TASSAX7nmtkhx1x9cFY4l49TBcZNAiNogBeR40N
          6ByawjbptznmjkADf9qdI8rLmeuTnr1GgjJsQBsS8qdomG4ITkEG0WJHIbOr0AAAGUAAAA
          DHJzYS1zaGEyLTUxMgAAAYCqcUD/BkdPxEc6RgaatVRyPllNTXA/7Oz7xK1ZGbhkvweO22
          itXpb/E1Cy/ir8pppAh2Trec0MPI3vgs6TLHcsOGQbtUMVckfY9SxErlq8H0dEjouzhvnt
          rvkNnRojfdeAUR+6UGhlZpiF8kPbNMrxkqw2Ir5uLkReZphXlw/Qg3DY/eQ2Hlns8Up9ql
          4OD+pfoOQtegy5FICjec7fXqlb5KgpazwNoENxh/QoomndHWntnNW7B/fiJL++vGoc6OX4
          KFxRPFKQoyemQXVa3K3Unli8hYI8o4YzcLiYJ6Uk6MR+RmYvyz7ZF469d1SoO1enDQFOzJ
          LSq0zaeFX9HmJ8/2rzKs7bnQKWUjm3C2KmyO/NtnZr/qB45tDlWNvuP7+phMfiJRvpvIyc
          JZdyc9T1CWrzlQoIUaH08gizmyP37NAgqzUTb3NAnhGb1dp70mTfORRnRoKQtzX/DiSfVZ
          EOk+qnuoJ7Gs4erWNRW2363SgbKKOhPCxeMfUY2zm628sAAAAEZmlsZQAAAAAAAAAGc2hh
          NTEyAAAAUwAAAAtzc2gtZWQyNTUxOQAAAED54YE97IiluG2xM7OFysEUQfhKEztaT+vvD3
          kxDq9mHz0Gr6uiKd/gKL+/yGHPAoif74khm/gUe/A9AI7+JvcH
          -----END SSH SIGNATURE-----
        SIG
      end

      it 'returns nil' do
        expect(signature.key_fingerprint).to be_nil
      end
    end
  end
end
