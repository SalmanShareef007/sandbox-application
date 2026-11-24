@description('PostgreSQL server FQDN (fully qualified domain name)')
param postgresServerFqdn string

@description('PostgreSQL server name')
param postgresServerName string

@description('PostgreSQL database name')
param postgresDatabaseName string

@description('Database administrator username')
param dbAdminUser string

@description('Database administrator password')
@secure()
param dbAdminPassword string

@description('Azure region for resource deployment')
param location string

// Create deployment script to initialize database
// This script connects to PostgreSQL and executes the schema creation
resource databaseInitScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'db-init-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    azPowerShellVersion: '11.0'
    timeout: 'PT30M'
    retentionInterval: 'PT1H'
    scriptContent: '''
      param(
        [string]$ServerFqdn,
        [string]$ServerName,
        [string]$DatabaseName,
        [string]$AdminUser,
        [string]$AdminPassword
      )
      
      # Install PostgreSQL client tools
      Write-Host "Installing postgresql-client..."
      choco install postgresql --no-progress -y 2>&1 | Out-Null
      
      # Set environment variables for psql
      $env:PGPASSWORD = $AdminPassword
      
      # Schema SQL - Inline the entire schema definition
      $schemaSql = @'
-- Platform Core Tables
CREATE TABLE IF NOT EXISTS platform_mutex (
  id SERIAL NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS platform_records (
  collection VARCHAR(80) NOT NULL,
  record_key VARCHAR(100) NOT NULL,
  position INTEGER NOT NULL,
  document JSON NOT NULL,
  PRIMARY KEY (collection, record_key)
);

CREATE TABLE IF NOT EXISTS reference_counters (
  prefix VARCHAR(10) NOT NULL,
  last_value INTEGER NOT NULL,
  PRIMARY KEY (prefix)
);

-- Users and Roles
CREATE TABLE IF NOT EXISTS roles (
  id UUID NOT NULL,
  name VARCHAR(50) NOT NULL,
  description VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS users (
  id UUID NOT NULL,
  entra_object_id UUID NOT NULL,
  entra_tenant_id UUID NOT NULL,
  email VARCHAR(255) NOT NULL,
  display_name VARCHAR(255),
  is_active BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_entra_identity ON users (entra_tenant_id, entra_object_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

CREATE TABLE IF NOT EXISTS user_roles (
  id UUID NOT NULL,
  user_id UUID NOT NULL,
  role_id UUID NOT NULL,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY(role_id) REFERENCES roles (id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_roles ON user_roles (user_id, role_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles (role_id);

-- Audit and Logging
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID NOT NULL,
  actor_user_id UUID,
  actor_identity VARCHAR(255),
  action VARCHAR(150) NOT NULL,
  entity_type VARCHAR(100),
  entity_id VARCHAR(100),
  details JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(actor_user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs (created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs (actor_user_id);

-- Sandbox Requests
CREATE TABLE IF NOT EXISTS sandbox_requests (
  id UUID NOT NULL,
  reference VARCHAR(20) NOT NULL,
  requested_by UUID NOT NULL,
  sandbox_name VARCHAR(150) NOT NULL,
  business_unit VARCHAR(100),
  business_unit_code VARCHAR(20),
  cost_center VARCHAR(100),
  workload VARCHAR(100),
  description TEXT,
  request_reason TEXT,
  location VARCHAR(100) NOT NULL,
  requested_role VARCHAR(50) NOT NULL,
  duration_days INTEGER,
  budget_amount NUMERIC(12, 2),
  monthly_budget NUMERIC(12, 2),
  owner_email VARCHAR(255),
  requestor_name VARCHAR(255),
  requestor_email VARCHAR(255),
  manager_email VARCHAR(255),
  principal_id VARCHAR(64),
  subscription_id VARCHAR(64),
  expiry_date DATE,
  pending_expiry_date DATE,
  resource_id TEXT,
  imported BOOLEAN DEFAULT false NOT NULL,
  decision_by VARCHAR(255),
  decision_reason TEXT,
  decided_at TIMESTAMP WITH TIME ZONE,
  failed_operation VARCHAR(30),
  last_error TEXT,
  operation_id VARCHAR(64),
  operation_in_progress VARCHAR(30),
  extra JSONB DEFAULT '{}' NOT NULL,
  status VARCHAR(30) DEFAULT 'pending' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(requested_by) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS idx_sandbox_requests_sandbox_name ON sandbox_requests (sandbox_name);
CREATE INDEX IF NOT EXISTS idx_sandbox_requests_created ON sandbox_requests (created_at);
CREATE INDEX IF NOT EXISTS idx_sandbox_requests_updated ON sandbox_requests (updated_at);
CREATE UNIQUE INDEX IF NOT EXISTS uq_sandbox_requests_reference ON sandbox_requests (reference);
CREATE INDEX IF NOT EXISTS idx_sandbox_requests_user ON sandbox_requests (requested_by);
CREATE INDEX IF NOT EXISTS idx_sandbox_requests_status ON sandbox_requests (status);

-- Sandboxes
CREATE TABLE IF NOT EXISTS sandboxes (
  id UUID NOT NULL,
  request_id UUID NOT NULL,
  sandbox_id VARCHAR(150) NOT NULL,
  owner_user_id UUID NOT NULL,
  resource_group_name VARCHAR(150) NOT NULL,
  location VARCHAR(100) NOT NULL,
  assigned_role VARCHAR(50) NOT NULL,
  status VARCHAR(30) DEFAULT 'provisioning' NOT NULL,
  budget_amount NUMERIC(12, 2),
  provisioned_at TIMESTAMP WITH TIME ZONE,
  expiry_date DATE,
  decommissioned_at TIMESTAMP WITH TIME ZONE,
  tags JSONB DEFAULT '{}',
  extra JSONB DEFAULT '{}' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(request_id) REFERENCES sandbox_requests (id),
  FOREIGN KEY(owner_user_id) REFERENCES users (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_sandboxes_request ON sandboxes (request_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_sandboxes_sandbox_id ON sandboxes (sandbox_id);
CREATE INDEX IF NOT EXISTS idx_sandboxes_status ON sandboxes (status);
CREATE INDEX IF NOT EXISTS idx_sandboxes_owner ON sandboxes (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_sandboxes_expiry ON sandboxes (expiry_date);

-- Sandbox History
CREATE TABLE IF NOT EXISTS sandbox_history (
  id UUID NOT NULL,
  sandbox_id UUID NOT NULL,
  changed_by UUID,
  previous_status VARCHAR(50),
  new_status VARCHAR(50) NOT NULL,
  change_reason TEXT,
  metadata JSONB DEFAULT '{}',
  changed_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(sandbox_id) REFERENCES sandboxes (id),
  FOREIGN KEY(changed_by) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_sandbox_history_sandbox ON sandbox_history (sandbox_id);
CREATE INDEX IF NOT EXISTS idx_sandbox_history_changed ON sandbox_history (changed_at);

-- Terraform Jobs
CREATE TABLE IF NOT EXISTS terraform_jobs (
  id UUID NOT NULL,
  sandbox_id UUID NOT NULL,
  triggered_by UUID,
  job_type VARCHAR(30) NOT NULL,
  operation VARCHAR(30),
  status VARCHAR(30) DEFAULT 'pending' NOT NULL,
  attempts INTEGER DEFAULT 0 NOT NULL,
  terraform_environment VARCHAR(50) DEFAULT 'dev',
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  exit_code INTEGER,
  summary TEXT,
  log_reference TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(sandbox_id) REFERENCES sandboxes (id),
  FOREIGN KEY(triggered_by) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS idx_terraform_jobs_sandbox ON terraform_jobs (sandbox_id);
CREATE INDEX IF NOT EXISTS idx_terraform_jobs_status ON terraform_jobs (status);

-- Terraform Logs
CREATE TABLE IF NOT EXISTS terraform_logs (
  id UUID NOT NULL,
  job_id UUID NOT NULL,
  log_level VARCHAR(20) DEFAULT 'INFO',
  log_stream VARCHAR(20),
  message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(job_id) REFERENCES terraform_jobs (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_terraform_logs_job ON terraform_logs (job_id);
CREATE INDEX IF NOT EXISTS idx_terraform_logs_created ON terraform_logs (created_at);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
  id VARCHAR(64) NOT NULL,
  request_id UUID,
  category VARCHAR(30) NOT NULL,
  title TEXT NOT NULL,
  audience VARCHAR(20) NOT NULL,
  recipient_text TEXT,
  recipients JSONB DEFAULT '[]' NOT NULL,
  cc_recipients JSONB DEFAULT '[]' NOT NULL,
  owner_object_id VARCHAR(64),
  owner_tenant_id VARCHAR(64),
  email_status VARCHAR(20) DEFAULT 'disabled' NOT NULL,
  attempts INTEGER DEFAULT 0 NOT NULL,
  email_error TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(request_id) REFERENCES sandbox_requests (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications (created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_owner ON notifications (owner_object_id, owner_tenant_id);
CREATE INDEX IF NOT EXISTS idx_notifications_pending ON notifications (email_status, attempts);

-- Request History
CREATE TABLE IF NOT EXISTS request_history (
  id BIGSERIAL NOT NULL,
  request_id UUID NOT NULL,
  status VARCHAR(50) NOT NULL,
  note TEXT,
  occurred_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(request_id) REFERENCES sandbox_requests (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_request_history_request ON request_history (request_id, id);

-- Decommission Requests
CREATE TABLE IF NOT EXISTS decommission_requests (
  id UUID NOT NULL,
  reference VARCHAR(20) NOT NULL,
  sandbox_id UUID NOT NULL,
  requested_by UUID,
  requested_by_identity VARCHAR(255),
  source VARCHAR(30),
  reason TEXT,
  expiry_date DATE,
  flagged_expiry DATE,
  cleanup_not_before DATE,
  decision_by VARCHAR(255),
  decision_reason TEXT,
  extra JSONB DEFAULT '{}' NOT NULL,
  status VARCHAR(30) DEFAULT 'pending' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(sandbox_id) REFERENCES sandboxes (id),
  FOREIGN KEY(requested_by) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS idx_decommission_sandbox ON decommission_requests (sandbox_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_decommission_requests_reference ON decommission_requests (reference);
CREATE INDEX IF NOT EXISTS idx_decommission_status ON decommission_requests (status);

-- Extension Requests
CREATE TABLE IF NOT EXISTS extension_requests (
  id UUID NOT NULL,
  reference VARCHAR(20) NOT NULL,
  sandbox_id UUID NOT NULL,
  requested_by UUID NOT NULL,
  current_expiry_date DATE NOT NULL,
  requested_expiry_date DATE NOT NULL,
  extension_days INTEGER NOT NULL,
  reason TEXT,
  decision_by VARCHAR(255),
  decision_reason TEXT,
  extra JSONB DEFAULT '{}' NOT NULL,
  status VARCHAR(30) DEFAULT 'pending' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(sandbox_id) REFERENCES sandboxes (id),
  FOREIGN KEY(requested_by) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS idx_extension_requests_status ON extension_requests (status);
CREATE INDEX IF NOT EXISTS idx_extension_requests_sandbox ON extension_requests (sandbox_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_extension_requests_reference ON extension_requests (reference);

-- Approvals
CREATE TABLE IF NOT EXISTS approvals (
  id UUID NOT NULL,
  sandbox_request_id UUID,
  extension_request_id UUID,
  decommission_request_id UUID,
  approver_user_id UUID NOT NULL,
  decision VARCHAR(20) NOT NULL,
  comments TEXT,
  approved_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY(sandbox_request_id) REFERENCES sandbox_requests (id),
  FOREIGN KEY(extension_request_id) REFERENCES extension_requests (id),
  FOREIGN KEY(decommission_request_id) REFERENCES decommission_requests (id),
  FOREIGN KEY(approver_user_id) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS idx_approvals_approver ON approvals (approver_user_id);
CREATE INDEX IF NOT EXISTS idx_approvals_sandbox_request ON approvals (sandbox_request_id);
CREATE INDEX IF NOT EXISTS idx_approvals_decommission_request ON approvals (decommission_request_id);
CREATE INDEX IF NOT EXISTS idx_approvals_extension_request ON approvals (extension_request_id);

-- Seed default roles if they don't exist
INSERT INTO roles (id, name, description) VALUES
  (gen_random_uuid(), 'Admin', 'Manages sandbox requests and approvals'),
  (gen_random_uuid(), 'User', 'Can request and manage assigned sandboxes')
ON CONFLICT (name) DO NOTHING;
'@
      
      # Create temporary SQL file
      $sqlFile = Join-Path $env:TEMP "schema_$(Get-Random).sql"
      $schemaSql | Out-File -FilePath $sqlFile -Encoding UTF8
      
      Write-Host "Database initialization script generated at: $sqlFile"
      Write-Host "Connecting to PostgreSQL server: $ServerFqdn"
      Write-Host "Database: $DatabaseName"
      
      # Execute schema creation script using psql
      $psqlPath = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
      if (-not (Test-Path $psqlPath)) {
        # Try to find psql in PATH
        $psqlPath = (Get-Command psql -ErrorAction SilentlyContinue).Source
        if (-not $psqlPath) {
          throw "PostgreSQL client (psql) not found. Please ensure PostgreSQL tools are installed."
        }
      }
      
      Write-Host "Using psql from: $psqlPath"
      
      # Execute the SQL script
      Write-Host "Executing schema creation script..."
      & $psqlPath -h $ServerFqdn -U "$AdminUser" -d $DatabaseName -f $sqlFile 2>&1 | Tee-Object -Variable output
      
      if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Database schema created successfully"
        $output | Write-Output
        
        # Verify table creation
        Write-Host "`nVerifying table creation..."
        $verifyScript = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
        & $psqlPath -h $ServerFqdn -U "$AdminUser" -d $DatabaseName -c $verifyScript 2>&1 | Write-Output
        
        # Cleanup
        Remove-Item -Path $sqlFile -Force -ErrorAction SilentlyContinue
        
        $DeploymentScriptOutputs = @{
          initStatus = "SUCCESS"
          message = "Database initialization completed successfully"
        }
      } else {
        Write-Error "Database initialization failed with exit code: $LASTEXITCODE"
        Write-Output "Error output: $output"
        $DeploymentScriptOutputs = @{
          initStatus = "FAILED"
          message = "Database initialization failed: $output"
        }
      }
    '''
    arguments: '-ServerFqdn "${postgresServerFqdn}" -ServerName "${postgresServerName}" -DatabaseName "${postgresDatabaseName}" -AdminUser "${dbAdminUser}" -AdminPassword "${dbAdminPassword}"'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: uniqueString(resourceGroup().id)
  }
}

output initStatus string = databaseInitScript.properties.outputs.initStatus
output initMessage string = databaseInitScript.properties.outputs.message
