import { DecimalPipe } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, OnInit, inject, signal } from '@angular/core';

interface HelloResponse {
  message: string;
  version: string;
  uptimeSeconds: number;
}

interface SecretStatusResponse {
  isConfigured: boolean;
  source: string | null;
  clientId: string | null;
  clientSecret: string | null;
}

@Component({
  selector: 'app-root',
  imports: [DecimalPipe],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App implements OnInit {
  private readonly http = inject(HttpClient);

  protected readonly greeting = signal<HelloResponse | null>(null);
  protected readonly errorMessage = signal('');
  protected readonly credentials = signal<SecretStatusResponse | null>(null);
  protected readonly credentialsError = signal('');

  ngOnInit(): void {
    this.http.get<HelloResponse>('/api/hello').subscribe({
      next: (response) => this.greeting.set(response),
      error: () => this.errorMessage.set('The API could not be reached. Make sure it is running and try again.'),
    });
    this.http.get<SecretStatusResponse>('/api/secret-status').subscribe({
      next: (response) => this.credentials.set(response),
      error: () => this.credentialsError.set('Could not load the simulated credentials.'),
    });
  }
}
