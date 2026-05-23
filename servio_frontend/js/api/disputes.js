import { api } from './client.js';

export const openDispute = (bookingId, body) =>
  api.post(`/payments/dispute/${bookingId}`, body);

export const getMyDisputes = () =>
  api.get('/payments/disputes/my');

export const getMyWorkerDisputes = () =>
  api.get('/payments/disputes/worker-mine');

export const getDisputeForParty = (id) =>
  api.get(`/payments/disputes/party/${id}`);

export const addDisputeEvidence = (id, body) =>
  api.post(`/payments/disputes/${id}/evidence`, body);

export const appealDispute = (id, body) =>
  api.post(`/payments/disputes/${id}/appeal`, body);
