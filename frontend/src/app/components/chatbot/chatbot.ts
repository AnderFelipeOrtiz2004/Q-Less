import { ChangeDetectorRef, Component, NgZone } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../services/auth.js';
import { ChatbotResponse, ChatbotService } from '../../services/chatbot.service';

interface ConversationMessage {
  role: 'user' | 'bot';
  text?: string;
  reply?: ChatbotResponse;
}

@Component({
  selector: 'app-chatbot',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './chatbot.html',
  styleUrl: './chatbot.css'
})
export class ChatbotComponent {
  prompt = '';
  isLoading = false;
  conversations: ConversationMessage[] = [
    {
      role: 'bot',
      text: 'Puedo ayudarte con maquetas y trabajos escolares usando el inventario real de Q-LESS. Preguntame que necesitas hacer y te dire que hay disponible, que hace falta y que alternativas puedes usar.'
    }
  ];

  constructor(
    private authService: AuthService,
    private router: Router,
    private chatbotService: ChatbotService,
    private ngZone: NgZone,
    private cdr: ChangeDetectorRef
  ) {}

  async sendMessage(): Promise<void> {
    const text = this.prompt.trim();
    if (!text || this.isLoading) {
      return;
    }

    this.conversations.push({ role: 'user', text });
    this.prompt = '';
    this.isLoading = true;

    try {
      const response = await this.chatbotService.recommend(text);

      this.ngZone.run(() => {
        this.conversations.push({
          role: 'bot',
          reply: response
        });
        this.isLoading = false;
        this.cdr.detectChanges();
      });
    } catch (error: any) {
      console.error('Error consultando chatbot', error);

      const backendMessage =
        error?.error?.message
        || error?.message
        || 'No pude consultar el inventario en este momento.';

      this.ngZone.run(() => {
        this.conversations.push({
          role: 'bot',
          text: `${backendMessage} Verifica que el backend este corriendo e intenta de nuevo.`
        });
        this.isLoading = false;
        this.cdr.detectChanges();
      });
    }
  }

  trackByIndex(index: number): number {
    return index;
  }

  get isAdmin(): boolean {
    return this.authService.isAdmin();
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}
